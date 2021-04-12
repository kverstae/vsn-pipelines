nextflow.enable.dsl=2

////////////////////////////////////////////////////////
//  Import sub-workflows/processes from the utils module:
include {
    PUBLISH as PUBLISH_SEURAT_RDS_SCALED;
} from '../../utils/workflows/utils.nf' params(params)

////////////////////////////////////////////////////////
//  Import sub-workflows/processes from the tool module:
include {
    SC__SEURAT__FIND_HIGHLY_VARIABLE_FEATURES;
} from '../processes/feature_selection.nf' params(params)
include {
    SC__SEURAT__SCALING;
} from '../processes/normalize_transform.nf' params(params)

workflow HVG_SELECTION {

    take:
        data

    main:
        hvg = SC__SEURAT__FIND_HIGHLY_VARIABLE_FEATURES( data )
        // TODO: REGRESS OUT
        scaled = SC__SEURAT__SCALING( hvg )

        PUBLISH_SEURAT_RDS_SCALED(
            scaled,
            'SEURAT.hvg_scaled_output',
            'Rds',
            'seurat',
            false
        )
    emit:
        hvg
        scaled
}