#!/usr/bin/env python
import os
from optparse import OptionParser

import numpy as np

import scanpy as sc

parser = OptionParser(
    usage="usage: %prog [options] h5ad_file_path",
    version="%prog 1.0"
)
parser.add_option(
    "-c", "--min-n-counts",
    type=int,
    action="store",
    dest="min_n_counts",
    default=-1,
    help="Filter out cells with less than the minimum n of counts."
)
parser.add_option(
    "-C", "--max-n-counts",
    type=int,
    action="store",
    dest="max_n_counts",
    default=-1,
    help="Filter out cells with more than the maximum n of counts."
)
parser.add_option(
    "-g", "--min-n-genes",
    type=int,
    action="store",
    dest="min_n_genes",
    default=-1,
    help="Filter out cells with less than the minimum n of genes expressed."
)
parser.add_option(
    "-G", "--max-n-genes",
    type=int,
    action="store",
    dest="max_n_genes",
    default=-1,
    help="Filter out cells with more than the maximum n of genes expressed."
)
parser.add_option(
    "-M", "--max-percent-mito",
    type=float,
    action="store",  # optional because action defaults to "store"
    dest="max_percent_mito",
    default=-1,
    help="Filter out cells with more than the maximum percentage of mitochondrial genes expressed."
)
#
parser.add_option(
    "-v", "--verbose",
    action="store_false",  # optional because action defaults to "store"
    dest="verbose",
    default=False,
    help="Show messages."
)

(options, args) = parser.parse_args()

# Define the arguments properly
FILE_PATH_IN = args[0]
FILE_PATH_OUT_BASENAME = os.path.splitext(args[1])[0]

# I/O
# Expects h5ad file
try:
    adata = sc.read_h5ad(filename=FILE_PATH_IN)
except:
    raise Exception("Wrong input format. Expects .h5ad files, got .{}".format(os.path.splitext(FILE_PATH_IN)[0]))


#
# Filter on min/Max number of counts
#

if options.min_n_counts > 0:
    adata = adata[adata.obs['n_counts'] > options.min_n_counts, :]

if options.max_n_counts > 0:
    adata = adata[adata.obs['n_counts'] < options.max_n_counts, :]

#
# Filter on min/Max number of genes
#

if options.min_n_genes > 0:
    sc.pp.filter_cells(adata, min_genes=options.min_n_genes)

if options.max_n_genes > 0:
    adata = adata[adata.obs['n_genes'] < options.max_n_genes, :]

#
# Filter on percentage of mitochondrial genes
#

if options.max_percent_mito > 0:
    adata = adata[adata.obs['percent_mito'] < options.max_percent_mito, :]

print(adata.obs.keys())

# I/O
adata.write_h5ad("{}.h5ad".format(FILE_PATH_OUT_BASENAME))

