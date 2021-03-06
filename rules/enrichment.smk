rule ascertain_annotation_is_sorted_by_db:
    input:
        members_file = "data/raw/global_enrichment_annotations/{taxId}.terms_members.tsv"
    output:
        flag_file = "data/interim/annotation_terms/{taxId}.is.sorted"
    shell:
        """
        uniq_etype_count=$(cut -f2 {input} | sort | uniq | wc -l)
        etype_count=$(cut -f2 {input} | uniq | wc -l) 
     
        if [ "$uniq_etype_count" == "$etype_count" ]; then
            touch {output}
        else
            echo "{input} is not sorted by database (aka etype)!"
            exit 1
        fi
        """

rule parse_term_lists:
    input:
        members_file = "data/raw/global_enrichment_annotations/{taxId}.terms_members.tsv",
        flag_file = "data/interim/annotation_terms/{taxId}.is.sorted"
    output:
        expand("data/interim/annotation_terms/{taxId}.term_list.{db}.rds", db = DATABASES, allow_missing = True)
    params:
        output_dir = lambda wildcards, output: os.path.dirname(output[0])
    log:
        log_file = "logs/parse_term_lists/{taxId}.log"
    conda:
        "../envs/r363.yml"
    script:
        "../scripts/parse_term_lists_by_db.R"


rule run_cameraPR:
    input:
        infile = "data/interim/filtered_deduplicated_user_inputs/{dataId}.{taxId}.input.tsv", 
        database_file = "data/interim/annotation_terms/{taxId}.term_list.{db}.rds",
        aggregated_infile = "data/interim/filtered_deduplicated_user_inputs.tsv" # need to provide just to properly connect dag
    output:
        output_file = "data/results/cameraPR/overlap_{_min}-{_max}/enrichment/{dataId}.{taxId}.{db}.tsv"
    params:
        min_overlap = "{_min}",#3
        max_overlap = "{_max}"#200
    log:
        log_file = "logs/run_cameraPR/overlap_{_min}-{_max}/{dataId}.{taxId}.{db}.log"
    conda:
        "../envs/r363.yml"
    script:
        "../scripts/run_cameraPR.R"
        


rule get_effect_size:
    input:
        enrichment_file = "data/results/cameraPR/overlap_{_min}-{_max}/enrichment/{dataId}.{taxId}.{db}.tsv",
        user_input_file = "data/interim/filtered_deduplicated_user_inputs/{dataId}.{taxId}.input.tsv"
    output:
        effect_file = "data/results/cameraPR/overlap_{_min}-{_max}/effect_size/{dataId}.{taxId}.{db}.tsv"
    log:
        log_file = "logs/get_effect_size/overlap_{_min}-{_max}/{dataId}.{taxId}.{db}.log"
    conda:
        "../envs/py38_sklearn.yml"
    shell:
        "python scripts/get_effect_size.py {input.enrichment_file} {input.user_input_file} {output} &> {log}"
        

# Collecting cameraPR output only after effect size calculation
def collect_cameraPR_output(wildcards):

    filtered_dedup_dir = checkpoints.apply_deduplication.get().output[1]
    DATAIDS, TAXIDS = glob_wildcards(os.path.join(filtered_dedup_dir,"{dataId}.{taxId}.input.tsv"))

    result_files =  expand(
                        expand("data/results/cameraPR/overlap_{_min}-{_max}/effect_size/{dataId}.{taxId}.{db}.tsv",
                        zip, dataId = DATAIDS, taxId = TAXIDS, allow_missing = True),
                    db = DATABASES, allow_missing = True)
                
    #result_files = [f for f in result_files if '83332' in f] + [f for f in result_files if 'zScfigOSQ47O' in f]
    #result_files = [f for f in result_files if 'PubMed' not in f]
    return result_files



rule collect_cameraPR:
    input:
        collect_cameraPR_output
    output:
        "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/aggregated.txt"
    log:
        "logs/collect_cameraPR/overlap_{_min}-{_max}.log"
    run:
        result_files_string = '\n'.join(input)+'\n'
        with open (output[0], 'w') as f:
            f.write(result_files_string)
            


rule write_cameraPR_termDf:
    input:
        enrichment_files_file = "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/aggregated.txt",
        species_taxIds_file = "data/raw/species.v11.0.txt"
    output:
        "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/sigTermDf_alpha"+str(ALPHA)+".tsv",
        "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/dataId_isSig_alpha"+str(ALPHA)+".tsv"
    params:
        alpha = ALPHA,
        n_grouped_species = 8,
        enrichment_method = "cameraPR",
        output_dir = lambda wildcards, input: os.path.dirname(input[0])
    log:
        "logs/write_cameraPR_termDf/overlap_{_min}-{_max}.log"
    conda:
        "../envs/py38_sklearn.yml"
    shell:
        "python scripts/read_enrichment_results.py {input.enrichment_files_file} {input.species_taxIds_file} {params.alpha} {params.n_grouped_species} {params.enrichment_method} {params.output_dir} &> {log}"



rule plot_enrichment_results:
    input:
        dataId_isSig_file = "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/dataId_isSig_alpha"+str(ALPHA)+".tsv",
        sigTerm_file = "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/sigTermDf_alpha"+str(ALPHA)+".tsv"
    output:
        "figures/cameraPR/overlap_{_min}-{_max}/enriched_terms/{species_subset}_species/at_least_one_significant_facetGrid.svg",
        "figures/cameraPR/overlap_{_min}-{_max}/enriched_terms/{species_subset}_species/at_least_one_significant_facetGrid_vertical.svg",
        "figures/cameraPR/overlap_{_min}-{_max}/enriched_terms/{species_subset}_species/nr_sig_terms_per_user_input.svg"
    params:
        output_dir = lambda wildcards, output: os.path.dirname(output[0]),
        species_subset = "{species_subset}"
    log:
        "logs/plot_enrichment_results/overlap_{_min}-{_max}.species_{species_subset}.log"
    conda:
        "../envs/py38_plotting.yml"
    shell:
        "python scripts/plot_enrichment_results.py {input.sigTerm_file} {input.dataId_isSig_file} {params.output_dir} {params.species_subset} &> {log}"
