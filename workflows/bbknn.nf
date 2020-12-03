nextflow.preview.dsl=2

////////////////////////////////////////////////////////
//  Import sub-workflows/processes from the utils module:
include {
    getBaseName;
} from '../src/utils/processes/files.nf'
include {
    clean;
    SC__FILE_CONVERTER;
    SC__FILE_CONCATENATOR;
} from '../src/utils/processes/utils.nf' params(params)
include {
    COMBINE_BY_PARAMS;
} from '../src/utils/workflows/utils.nf' params(params)
include {
    FINALIZE;
} from '../src/utils/workflows/finalize.nf' params(params)
include {
    FILTER_AND_ANNOTATE_AND_CLEAN;
} from '../src/utils/workflows/filterAnnotateClean.nf' params(params)
include {
    UTILS__GENERATE_WORKFLOW_CONFIG_REPORT;
} from '../src/utils/processes/reports.nf' params(params)

////////////////////////////////////////////////////////
//  Import sub-workflows/processes from the tool module:
include {
    QC_FILTER;
} from '../src/scanpy/workflows/qc_filter.nf' params(params)
include {
    NORMALIZE_TRANSFORM;
} from '../src/scanpy/workflows/normalize_transform.nf' params(params)
include {
    HVG_SELECTION;
} from '../src/scanpy/workflows/hvg_selection.nf' params(params)
include {
    NEIGHBORHOOD_GRAPH;
} from '../src/scanpy/workflows/neighborhood_graph.nf' params(params)
include {
    DIM_REDUCTION_PCA;
} from '../src/scanpy/workflows/dim_reduction_pca.nf' params(params)
include {
    DIM_REDUCTION_TSNE_UMAP;
} from '../src/scanpy/workflows/dim_reduction.nf' params(params)
// cluster identification
include {
    SC__SCANPY__CLUSTERING_PARAMS;
} from '../src/scanpy/processes/cluster.nf' params(params)
include {
    CLUSTER_IDENTIFICATION;
} from '../src/scanpy/workflows/cluster_identification.nf' params(params)
include {
    BEC_BBKNN;
} from '../src/scanpy/workflows/bec_bbknn.nf' params(params)
include {
    SC__DIRECTS__SELECT_DEFAULT_CLUSTERING
} from '../src/directs/processes/selectDefaultClustering.nf'
// tool reporting:
include {
    SC__SCANPY__MERGE_REPORTS;
    SC__SCANPY__REPORT_TO_HTML;
} from '../src/scanpy/processes/reports.nf' params(params)


workflow bbknn {

    take:
        data

    main:
        /*******************************************
        * Data processing
        */
        out = data | \
            SC__FILE_CONVERTER | \
            FILTER_AND_ANNOTATE_AND_CLEAN

        if(params.sc.scanpy.containsKey("filter")) {
            out = QC_FILTER( out ).filtered // Remove concat
        }
        if(params.sc.containsKey("file_concatenator")) {
            out = SC__FILE_CONCATENATOR( 
                out.map {
                    it -> it[1]
                }.toSortedList( 
                    { a, b -> getBaseName(a, "SC") <=> getBaseName(b, "SC") }
                ) 
            )
        }
        if(params.sc.scanpy.containsKey("data_transformation") && params.sc.scanpy.containsKey("normalization")) {
            out = NORMALIZE_TRANSFORM( out )
        }
        out = HVG_SELECTION( out )
        DIM_REDUCTION_PCA( out.scaled )
        NEIGHBORHOOD_GRAPH( DIM_REDUCTION_PCA.out )
        DIM_REDUCTION_TSNE_UMAP( NEIGHBORHOOD_GRAPH.out )

        // Perform the clustering step w/o batch effect correction (for comparison matter)
        clusterIdentificationPreBatchEffectCorrection = CLUSTER_IDENTIFICATION( 
            NORMALIZE_TRANSFORM.out,
            DIM_REDUCTION_TSNE_UMAP.out.dimred_tsne_umap,
            "Pre Batch Effect Correction"
        )

        // Perform the batch effect correction
        BEC_BBKNN(
            NORMALIZE_TRANSFORM.out,
            // Include only PCA and t-SNE pre-merge dim reductions. Omit UMAP for clarity since it will have to be overwritten by BEC_BBKNN
            DIM_REDUCTION_TSNE_UMAP.out.dimred_tsne,
            clusterIdentificationPreBatchEffectCorrection.marker_genes
        )

        // Finalize
        FINALIZE(
            params.sc?.file_concatenator ? SC__FILE_CONCATENATOR.out : SC__FILE_CONVERTER.out,
            BEC_BBKNN.out.data,
            'BBKNN.final_output'
        )

        // Define the parameters for clustering
        def clusteringParams = SC__SCANPY__CLUSTERING_PARAMS( clean(params.sc.scanpy.clustering) )

        // Select a default clustering when in parameter exploration mode
        if(params.sc.containsKey("directs") && clusteringParams.isParameterExplorationModeOn()) {
            scopeloom = SC__DIRECTS__SELECT_DEFAULT_CLUSTERING( FINALIZE.out.scopeloom )
        } else {
            scopeloom = FINALIZE.out.scopeloom
        }

        /*******************************************
        * Reporting
        */

        project = BEC_BBKNN.out.data.map { it -> it[0] }
        UTILS__GENERATE_WORKFLOW_CONFIG_REPORT(
            file(workflow.projectDir + params.utils.workflow_configuration.report_ipynb)
        )

        // Collect the reports:
        // Pairing clustering reports with bec reports
        if(!clusteringParams.isParameterExplorationModeOn()) {
            clusteringBECReports = BEC_BBKNN.out.cluster_report.map {
                it -> tuple(it[0], it[1])
            }.combine(
                BEC_BBKNN.out.bbknn_report.map {
                    it -> tuple(it[0], it[1])
                },
                by: 0
            ).map {
                it -> tuple(it[0], *it[1..it.size()-1], null)
            }
        } else {
            clusteringBECReports = COMBINE_BY_PARAMS(
                BEC_BBKNN.out.cluster_report.map { 
                    it -> tuple(it[0], it[1], *it[2])
                },
                BEC_BBKNN.out.bbknn_report,
                clusteringParams
            )
        }
        ipynbs = project.combine(
            UTILS__GENERATE_WORKFLOW_CONFIG_REPORT.out
        ).join(
            HVG_SELECTION.out.report.map {
                it -> tuple(it[0], it[1])
            }
        ).combine(
            clusteringBECReports,
            by: 0
        ).map {
            it -> tuple(it[0], it[1..it.size()-2], it[it.size()-1])
        }

        // reporting:
        SC__SCANPY__MERGE_REPORTS(
            ipynbs,
            "merged_report",
            clusteringParams.isParameterExplorationModeOn()
        )
        SC__SCANPY__REPORT_TO_HTML(SC__SCANPY__MERGE_REPORTS.out)

    emit:
        filteredloom = FINALIZE.out.filteredloom
        scopeloom = scopeloom
        scanpyh5ad = FINALIZE.out.scanpyh5ad

}
