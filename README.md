# Reducing the Human Effort in Text Line Segmentation for Historical Documents
This repository contains the scripts used for the experimentation made for reducing the human effort in text line segmentation for historical documents.

The experiments were performed in two historical corpora:

* [HisClima](https://zenodo.org/record/4106887#.X43VHHUzais
) 
* [Oficio de Hipotecas de Girona](https://zenodo.org/record/1322666)

The partitions used for each corpus can be found in: [./data](./data).


Requirements:

* [P2PaLA](https://github.com/lquirosd/P2PaLA)


The experiments were performed by using this [script](./scripts/DLA_iterative_training.sh).



Please cite our paper if you find it useful for your research.

```
@inproceedings{granell_reducing_2021,
  author = {E. Granell and L. Quirós and V. Romero and J.-A. Sánchez},
  booktitle = {Proceedings of the 16th International Conference on Document Analysis and Recognition (ICDAR)},
  title = {Reducing the Human Effort in Text Line Segmentation for Historical Documents},
  year = {2021}
}
```
