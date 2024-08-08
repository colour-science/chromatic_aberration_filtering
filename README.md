
# Blind Chromatic Aberration Correction with False Color Filtering

| <img src="https://raw.githubusercontent.com/colour-science/chromatic_aberration_filtering/feature/wheels/images/teaser_blurry.png" width="230px"/> | <img src="https://raw.githubusercontent.com/colour-science/chromatic_aberration_filtering/feature/wheels/images/teaser_restored.png" width="230px"/> |
|:--------------------------------------------------------------------------------------------------------------------------------------------------:|:----------------------------------------------------------------------------------------------------------------------------------------------------:|
|                                                               <i>Aberrated image</i>                                                               |                                                                <i>Filtered result</i>                                                                |

This repository contains a non-official [Cython](https://cython.org) implementation of the IEEE Transactions on Image Processing 2013 article [Correction of Axial and Lateral Chromatic Aberration With False Color Filter](https://ieeexplore.ieee.org/document/6357254) by Joonyoung Chang, Hee Kang and Moon Gi Kang.

The method consists in a 1D filter independently run on the columns and rows of an image containing chromatic aberrations. Merging the horizontally and vertically filtered outputs yields the final restored image. Our implementation leverages the multi-threading abilities of Cython to achieve restoration on large images in less than 1 second.

This implementation is part of an [IPOL](https://www.ipol.im) paper describing in the detail the method. If this code is useful to your research, please cite our paper [paper](https://www.ipol.im/pub/art/2023/443/article.pdf).

## News

10/19: Try the [online demo](https://ipolcore.ipol.im/demo/clientApp/demo.html?id=443) using the code!

## Requirements

### macOS

To benefit from parallelism, [OpenMP](https://openmp.llvm.org) needs to be installed alongside [LLVM](https://llvm.org).

Assuming [Homebrew](https://brew.sh) is available, their installation is as follows:
 
```bash
brew install libomp llvm
```

The following [Poetry](https://python-poetry.org) command can be used to install the remaining build requirements:

```bash
poetry install
```

## Configuring

[Meson](https://mesonbuild.com/) is used to build the Cython extension, the project can be configured as follows:

```bash
poetry run meson build
```

## Building an Editable Build

### macOS

```bash
CC=$(brew --prefix llvm)/bin/clang poetry run pip install --no-build-isolation --editable .
```

The **Cython** extension will be installed in the **Poetry** virtual environement and available for import.

## Building a Wheel

### macOS

```bash
CC=$(brew --prefix llvm)/bin/clang poetry run python -m build
```

The **wheel** will be available in the `dist` directory.

## Usage

The **Cython** extension can be imported as follows:

```python
import chromatic_aberration_correction
```

Then the function to correct chromatic aberration is available to use:

```python
chromatic_aberration_correction.correct_chromatic_aberration
```

Examples are available in the examples directory: [examples/example_correction.py](examples/example_correction.py)

Note that on macOS, for best performance, it is recommended to set the number of *OpenMP* threads to 1:

```bash
export OMP_NUM_THREADS=1
```

## Contact 

If you encounter any problem with the code, please use the following contacts:

- <thomas.eboli@ens-paris-saclay.fr>
- <colour-developers@colour-science.org>
