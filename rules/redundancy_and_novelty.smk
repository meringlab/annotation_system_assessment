
rule calc_database_novelty:
    input:
        file_sigTermDf = "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/sigTermDf_alpha"+str(ALPHA)+".tsv",
    output:
        file_sigTermDf_novelty = "data/results/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/sigTermDf_unique_terms_across_and_within_databases.tsv", 
        file_novel_term_count = "data/results/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/unique_term_count_across_and_within_databases.tsv"  
    log:
        "logs/calc_database_novelty/overlap_{_min}-{_max}.log"
    conda:
        "../envs/py38_sklearn.yml"
    shell:
        "python scripts/calc_database_novelty.py {input} {output} &> {log}"
        
        
rule discard_enriched_term_subsets:
    input:
        file_sigTermDf = "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/sigTermDf_alpha"+str(ALPHA)+".tsv",
    output:
        file_nonredundant_term_count = "data/results/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/unique_term_count_within_databases.tsv"  
    log:
        "logs/discard_enriched_term_subsets/overlap_{_min}-{_max}.log"
    conda:
        "../envs/py38_sklearn.yml"
    shell:
        "python scripts/discard_enriched_term_subsets.py {input} {output} &> {log}"


rule plot_non_redundant_terms:
    input:
        file_nonredundant_term_count = "data/results/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/unique_term_count_within_databases.tsv"
    output:
        plot_file         = "figures/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/all_species/nr_nonredundant_sig_terms_per_user_input.svg",
        plot_reduced_file = "figures/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/reduced_species/nr_nonredundant_sig_terms_per_user_input.svg"
    log:
        "logs/plot_non_redundant_terms/overlap_{_min}-{_max}.log"
    conda:
        "../envs/py38_sklearn.yml"
    shell:
        "python scripts/plot_non_redundant_terms.py {input} {output} &> {log}"


rule plot_database_novelty:
    input:
        dataId_isSig_file     = "data/results/cameraPR/overlap_{_min}-{_max}/aggregation/dataId_isSig_alpha"+str(ALPHA)+".tsv",
        unique_sigTermDf_file = "data/results/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/sigTermDf_unique_terms_across_and_within_databases.tsv"
    output:
        novelty_plot_file         = "figures/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/all_species/at_least_one_novel_significant.svg",
        novelty_plot_reduced_file = "figures/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/reduced_species/at_least_one_novel_significant.svg",
        novel_count_file = "data/results/cameraPR/overlap_{_min}-{_max}/redundancy_and_novelty/novel_enriched_count.tsv"
    log:
        "logs/plot_database_novelty/overlap_{_min}-{_max}.log"
    conda:
        "../envs/py38_sklearn.yml"
    shell:
        "python scripts/plot_database_novelty.py {input} {output} &> {log}"
