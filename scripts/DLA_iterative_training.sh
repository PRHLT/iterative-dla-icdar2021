#! /bin/bash

# Default values
stage=0
unique_stage=true
P2PaLA_PATH="./tools/P2PaLA"
OHG_PATH="corpus/OHG"
HisClima_PATH="corpus/HisClima"
corpus="OHG" # OHG/HisClima
mode="supervised" # supervised / unsupervised
selection="most" # most confident / less confident / randomly
max_iterations=100
threshold=0.9
selection_size=5
iteration=1

if [ $# -eq 0 ]; then
  echo "########################################"
  echo "Use: bash ${0##*/} [options]"
  echo "Options:"
  echo " -s Stage: [0: Data preparation,"
  echo "            1: P2PaLA configuration,"
  echo "            2: Training touchstone model,"
  echo "            3: Training oracle model,"
  echo "            4: Iterative training loop]"
  echo " -u Unique stage: $unique_stage"
  echo " -p Path to P2PaLA: $P2PaLA_PATH"
  echo " -o Path to OHG: $OHG_PATH"
  echo " -h Path to HisClima: $HisClima_PATH"
  echo " -c Corpus for experiments: $corpus"
  echo " -m Supervision mode:$mode"
  echo " -S Selection mode: $selection"
  echo " -M Maximum number of iterations: $max_iterations"
  echo " -t Threshold: $threshold"
  echo " -z Selection_size: $selection_size"
  echo " -i Initial iteration: $iteration"
  echo "########################################"
  exit 0
fi

while getopts s:u:p:o:h:c:m:s:M:t:S:i:z: flag
do
  case "${flag}" in
    s) stage=${OPTARG};;
    u) unique_stage=${OPTARG};;
    p) P2PaLA_PATH=${OPTARG};;
    o) OHG_PATH=${OPTARG};;
    h) HisClima_PATH=${OPTARG};;
    c) corpus=${OPTARG};;
    m) mode=${OPTARG};;
    S) selection=${OPTARG};;
    M) max_iterations=${OPTARG};;
    t) threshold=${OPTARG};;
    z) selection_size=${OPTARG};;
    i) iteration=${OPTARG};;
  esac
done

echo "########################################"
echo "Running the script with the following parameters"
echo " Stage: $stage"
echo " Unique stage: $unique_stage"
echo " Path to P2PaLA: $P2PaLA_PATH"
echo " Path to OHG: $OHG_PATH"
echo " Path to HisClima: $HisClima_PATH"
echo " Corpus for experiments: $corpus"
echo " Supervision mode:$mode"
echo " Selection mode: $selection"
echo " Maximum number of iterations: $max_iterations"
echo " Threshold: $threshold"
echo " Selection size: $selection_size"
echo " Initial iteration: $iteration"
echo "########################################"


# Prepare the data
if [ $stage -le 0 ]; then
  echo "########################################"
  echo "# Preparing the data for $corpus "
  echo "########################################"
  
  [ ! -d data_"${corpus}" ] && mkdir -p data_"${corpus}"/{production,train,val,test}/page
  [ ! -d PARTITIONS_"${corpus}" ] && mkdir PARTITIONS_"${corpus}"

  case "$corpus" in
    "OHG")
      [ ! -d GT_"${corpus}" ] && ln -s "$OHG_PATH" ./GT_"${corpus}"
      find  ./GT_"${corpus}"/b0{04,05,06,07,08,09,10}/ -name "*tif" | sort -R > PARTITIONS_"${corpus}"/tmp.lst
      head -n 50 PARTITIONS_"${corpus}"/tmp.lst > PARTITIONS_"${corpus}"/test.lst
      head -n 55 PARTITIONS_"${corpus}"/tmp.lst | tail -n 5 > PARTITIONS_"${corpus}"/train.lst
      head -n 70 PARTITIONS_"${corpus}"/tmp.lst | tail -n 15 > PARTITIONS_"${corpus}"/val.lst
      tail -n +71 PARTITIONS_"${corpus}"/tmp.lst > PARTITIONS_"${corpus}"/production.lst
      rm PARTITIONS_"${corpus}"/tmp.lst

      for part in "train" "production" "val" "test"; do
        while read sample; do
          ln -s ../../"${sample}" data_"${corpus}"/"${part}"/;
          ln -s ../../../"$(dirname "${sample}")"/page/"$(basename "${sample}" .tif)".xml data_"${corpus}"/"${part}"/page/
        done < PARTITIONS_"${corpus}"/"${part}".lst
      done
    ;;

    "HisClima")
      split -l 138 PARTITIONS_"${corpus}"/train_full.lst
      mv xaa PARTITIONS_"${corpus}"/production.lst
      mv xab PARTITIONS_"${corpus}"/train.lst

      for part in "train" "production" "val" "test"; do
        while read sample; do
          ln -s ../../"${HisClima_PATH}"/"${sample}".jpg data_"${corpus}"/${part}/
          ln -s ../../../"${HisClima_PATH}"/page/"${sample}".xml data_"${corpus}"/${part}/page/
        done < PARTITIONS_"${corpus}"/${part}.lst
      done
    ;;
  esac

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

# Prepare the configuration files for P2PaLA
if [ $stage -le 1 ]; then
  echo "########################################"
  echo "# Preparing the P2PaLA configuration files"
  echo "########################################"

  [ ! -d conf ] && mkdir conf

# Configuration file for OHG
  cat << EOF> conf/P2PaLA_OHG.conf
--exp_name OHG_iterative
--gpu 0
--seed 42
--work_dir ./work_OHG
--log_level DEBUG
--num_workers 4
--img_size 1024 768
--line_color 128
--line_width 8
--regions \$pag \$nop \$tip \$par \$not \$pac
--approx_alg optimal
--num_segments 4
--batch_size 4
--input_channels 3
--out_mode L
--net_out_type C
--cnn_ngf 64
--adam_lr 0.001
--adam_beta1 0.5
--adam_beta2 0.999
--do_train
--tr_data ./data_OHG/iter_train/
--do_val
--val_data ./data_OHG/val/
--do_test
--te_data ./data_OHG/test/
--do_prod
--prod_data ./data_OHG/iter_prod/
--epochs 200
--use_gan
--save_adversarial_prob true
--max_vertex 30
--e_stdv 6
--save_prob_mat false
EOF

# Configuration file for HisClima
  cat << EOF> conf/P2PaLA_HisClima.conf
--gpu 0
--seed 42
--exp_name HisClima_iterative
--work_dir ./work_HisClima
--log_level DEBUG
--num_workers 4
--img_size 1024 768
--line_color 128
--line_width 4
--approx_alg optimal
--num_segments 2
--batch_size 4
--input_channels 3
--out_mode L
--net_out_type C
--cnn_ngf 64
--loss_lambda 100
--g_loss L1
--adam_lr 0.001
--adam_beta1 0.5
--adam_beta2 0.999
--epochs 200
--max_vertex 30
--e_stdv 6
--min_area 0.01
--do_train
--tr_data ./data_HisClima/iter_train/
--do_val
--val_data ./data_HisClima/val/
--do_test
--te_data ./data_HisClima/test/
--do_prod
--prod_data ./data_HisClima/iter_prod/
--use_gan
--save_adversarial_prob true
--save_prob_mat false
EOF

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

# Train the touchstone P2PaLA model
if [ $stage -le 2 ]; then
  echo "########################################"
  echo "# Training the touchstone model"
  echo "########################################"

  [ ! -d logs ] && mkdir logs 
  [ -d data_"${corpus}"/iter_train ] && rm -r data_"${corpus}"/iter_train
  cp -r data_"${corpus}"/train data_"${corpus}"/iter_train/
  [ -d data_"${corpus}"/iter_prod ] && rm -r data_"${corpus}"/iter_prod
  cp -r data_"${corpus}"/production data_"${corpus}"/iter_prod/

  work=work_"${corpus}"_touchstone
  [ -d "$work" ] && rm -r "$work"


  iteration=0
  echo "Training pages: $(find ./data_"${corpus}"/iter_train/ -maxdepth 1 -name '*.tif' -o -name '*jpg' | wc -l)" | tee logs/"${corpus}"_iterative_train_"${iteration}".log
  echo "Confidence threshold: $threshold" | tee -a logs/"${corpus}"_iterative_train_"${iteration}".log

  python3.7 "${P2PaLA_PATH}"/P2PaLA.py \
    --config conf/P2PaLA_"${corpus}".conf \
    --work_dir "${work}" \
    --log_comment "${corpus}_iterative_train_${iteration}" 2>> logs/"${corpus}"_iterative_train_"${iteration}".log

  cp "${work}"/results/test/adversarial_prob{,_"${iteration}"}.csv
  cp "${work}"/results/prod/adversarial_prob{,_"${iteration}"}.csv
  rm "${work}"/checkpoints/checkpoint.pth

  # Get results for test set
  find data_"${corpus}"/test/page -name "*xml" > /tmp/ref
  find "${work}"/results/test/page -name "*xml" > /tmp/hyp
  python3.7 "${P2PaLA_PATH}"/evalTools/page2page_eval.py \
    --target_list /tmp/ref \
    --hyp_list /tmp/hyp 2>> logs/"${corpus}"_iterative_train_"${iteration}".log

  # Get results for the production set
  find data_"${corpus}"/iter_prod/page -name "*xml" > /tmp/ref
  find "${work}"/results/prod/page -name "*xml" > /tmp/hyp
  python3.7 "${P2PaLA_PATH}"/evalTools/page2page_eval.py \
    --target_list /tmp/ref \
      --hyp_list /tmp/hyp 2>> logs/"${corpus}"_iterative_train_"${iteration}".log

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi

# Train the oracle P2PaLA model
if [ $stage -le 3 ]; then
  echo "########################################"
  echo "# Training the oracle model"
  echo "########################################"

  [ ! -d logs ] && mkdir logs 
  [ -d data_"${corpus}"/iter_train ] && rm -r data_"${corpus}"/iter_train
  cp -r data_"${corpus}"/train data_"${corpus}"/iter_train/
  cp -r data_"${corpus}"/production/* data_"${corpus}"/iter_train/
  [ -d data_"${corpus}"/iter_prod ] && rm -r data_"${corpus}"/iter_prod
  cp -r data_"${corpus}"/production data_"${corpus}"/iter_prod/

  work=work_"${corpus}"_oracle
  [ -d $work ] && rm -r $work

  iteration=-1
  echo "Training pages: $(find ./data_"${corpus}"/iter_train/ -maxdepth 1 -name '*.tif' -o -name '*jpg' | wc -l)" | tee logs/"${corpus}"_iterative_train_"${iteration}".log
  echo "Confidence threshold: $threshold" | tee -a logs/"${corpus}"_iterative_train_"${iteration}".log

  python3.7 "${P2PaLA_PATH}"/P2PaLA.py \
    --config conf/P2PaLA_"${corpus}".conf \
    --work_dir "${work}" \
    --log_comment "${corpus}_iterative_train_${iteration}" 2>> logs/"${corpus}"_iterative_train_"${iteration}".log

  cp "${work}"/results/test/adversarial_prob{,_"${iteration}"}.csv
  cp "${work}"/results/prod/adversarial_prob{,_"${iteration}"}.csv
  rm "${work}"/checkpoints/checkpoint.pth

  # Get results for test set
  find data_"${corpus}"/test/page -name "*xml" > /tmp/ref
  find "${work}"/results/test/page -name "*xml" > /tmp/hyp
  python3.7 "${P2PaLA_PATH}"/evalTools/page2page_eval.py \
    --target_list /tmp/ref \
    --hyp_list /tmp/hyp 2>> logs/"${corpus}"_iterative_train_"${iteration}".log

  # Get results for the production set
  find data_"${corpus}"/iter_prod/page -name "*xml" > /tmp/ref
  find "${work}"/results/prod/page -name "*xml" > /tmp/hyp
  python3.7 "${P2PaLA_PATH}"/evalTools/page2page_eval.py \
    --target_list /tmp/ref \
      --hyp_list /tmp/hyp 2>> logs/"${corpus}"_iterative_train_"${iteration}".log

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi
# Iterative train P2PaLA models: supervised / unsupervised
if [ $stage -le 4 ]; then
  echo "########################################"
  echo "# Iterative training"
  echo "########################################"

  [ ! -d logs ] && mkdir logs
  work=work_"${corpus}"_"${mode}"_"${selection}"

  if [ $iteration -le 1 ]; then
    [ -d data_"${corpus}"/iter_train ] && rm -r data_"${corpus}"/iter_train
    cp -r data_"${corpus}"/train data_"${corpus}"/iter_train/
    [ -d data_"${corpus}"/iter_prod ] && rm -r data_"${corpus}"/iter_prod
    cp -r data_"${corpus}"/production data_"${corpus}"/iter_prod/
    [ -d "$work" ] && rm -r "$work"
    cp -r work_"${corpus}"_touchstone "$work"
  fi

  for iteration in $(seq $iteration $max_iterations); do
    echo "########################################"
    echo "# Iteration: ${iteration}"
    echo "########################################"

    log=logs/"${corpus}"_"${mode}"_"${selection}"_iterative_train_"${iteration}".log
    [ -f "$log" ] && rm "$log"

    case "${selection}" in
      "most")
        sed 's/\(.*\),\(.*\)/\1 \2/' "${work}"/results/prod/adversarial_prob_$((iteration - 1)).csv | tr '.' ',' | \
          sort -nrk2 | head -n $selection_size | rev | sed 's/,/\./' | rev | \
          awk -v threshold=${threshold} '{if ('NR==1' || threshold<$2) print $0}' > "${work}"/results/prod/adversarial_prob_sorted_$((iteration - 1)).csv
      ;;
      "less")
        sed 's/\(.*\),\(.*\)/\1 \2/' "${work}"/results/prod/adversarial_prob_$((iteration - 1)).csv | tr '.' ',' | \
          sort -nk2 | head -n $selection_size | rev | sed 's/,/\./' | rev | \
          awk -v threshold=${threshold} '{if ('NR==1' || threshold>$2) print $0}' > "${work}"/results/prod/adversarial_prob_sorted_$((iteration - 1)).csv
        ;;
      *)
        sed 's/\(.*\),\(.*\)/\1 \2/' "${work}"/results/prod/adversarial_prob_$((iteration - 1)).csv | tr '.' ',' | \
          shuf | head -n $selection_size > "${work}"/results/prod/adversarial_prob_sorted_$((iteration - 1)).csv
    esac

    while read sample; do
      conf=$(echo "$sample" | tr ',' '.' | awk '{print $2}')
      id=$(echo "$sample" | awk '{print $1}')
      echo "Added ${id} for the next training iteration with confidence $conf" >> "$log"
      case "$corpus" in
        "OHG")
          [ ! -f data_"${corpus}"/iter_train/"${id}".* ] && ln -s ../../data_"${corpus}"/production/"${id}".tif data_"${corpus}"/iter_train/ ;;
        "HisClima")
          [ ! -f data_"${corpus}"/iter_train/"${id}".* ] && ln -s ../../data_"${corpus}"/production/"${id}".jpg data_"${corpus}"/iter_train/ ;;
      esac

      if [[ "$mode" == "supervised" ]]; then
        # The supervised samples are not processed a second time
        rm ./data_"${corpus}"/iter_prod/"${id}".*
        mv ./data_"${corpus}"/iter_prod/page/"${id}".xml data_"${corpus}"/iter_train/page/
        rm ./"${work}"/results/prod/"${id}".*
        rm ./"${work}"/results/prod/page/"${id}".xml
      else
        rm ./"${work}"/results/prod/"${id}".*
        mv ./"${work}"/results/prod/page/"${id}".xml data_"${corpus}"/iter_train/page/
      fi
    done < ./"${work}"/results/prod/adversarial_prob_sorted_$((iteration - 1)).csv

    # Update the threshold if the confidence of the last selected sample is higher than it
    if (( $(echo "$threshold < $conf" | bc -l) )); then
      threshold=$conf
    fi

    echo "Training pages: $(find ./data_"${corpus}"/iter_train/ -maxdepth 1 -name '*.tif' -o -name '*jpg' | wc -l)" | tee -a "$log"
    echo "Confidence threshold: $threshold" | tee -a "$log"

    if [[ -f ./"${work}"/checkpoints/best_undervalNLLcriterion.pth ]]; then
      python3.7 "${P2PaLA_PATH}"/P2PaLA.py \
        --config conf/P2PaLA_"${corpus}".conf \
        --cont_train \
        --prev_model ./"${work}"/checkpoints/best_undervalNLLcriterion.pth \
        --work_dir "${work}" \
        --log_comment "${corpus}_${mode}_iterative_train_${iteration}" 2>> "$log"
    else
      python3.7 "${P2PaLA_PATH}"/P2PaLA.py \
        --config conf/P2PaLA_"${corpus}".conf \
        --work_dir "${work}" \
        --log_comment "${corpus}_${mode}_iterative_train_${iteration}" 2>> "$log"
    fi

    cp ./"${work}"/results/test/adversarial_prob{,_"${iteration}"}.csv
    cp ./"${work}"/results/prod/adversarial_prob{,_"${iteration}"}.csv
    cp ./"${work}"/checkpoints/best_undervalNLLcriterion{,_"${iteration}"}.pth
    rm work_"${corpus}"/checkpoints/checkpoint.pth

    
    echo "########################################"
    echo "# Get results for the test set"
    echo "########################################"
    find data_"${corpus}"/test/page -name "*xml" > /tmp/ref
    find ./"${work}"/results/test/page -name "*xml" > /tmp/hyp
    python3.7 "${P2PaLA_PATH}"/evalTools/page2page_eval.py \
      --target_list /tmp/ref \
      --hyp_list /tmp/hyp 2>> "$log"

    echo "########################################"
    echo "# Get results for the production set"
    echo "########################################"
    find data_"${corpus}"/iter_prod/page -name "*xml" > /tmp/ref
    find ./"${work}"/results/prod/page -name "*xml" > /tmp/hyp
    python3.7 "${P2PaLA_PATH}"/evalTools/page2page_eval.py \
      --target_list /tmp/ref \
      --hyp_list /tmp/hyp 2>> "$log"

  done

  if [ "$unique_stage" == "true" ]; then
    exit 0
  fi
fi
