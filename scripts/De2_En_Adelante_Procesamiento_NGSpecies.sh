#NO ES UN SCRIPT DE PROCESAMIENTO. Es un registro de los pasos

#Eliminado de secuencias corruptas: ver Process_Fastq.4_SeqKit.sh

#Trimmeado de cebadores: Trim_fastq.sh

#Filtrado de secuencias por longitud y calidad: ver Filtrado_Fastqs_2.sh

#Clusterizado - ver Clustering_NGSpecies.sh

#Unificado - ver Unificar_Clusters_NG.sh

#importado

qiime tools import \
  --type 'FeatureData[Sequence]' \
  --input-path /home/adriano_abb/Qiime/Res_Experim/expCOI/clustered/Consensos_unificado/consensos_todos.fasta \
  --output-path /home/adriano_abb/Qiime/Res_Experim/expCOI/clustered/Consensos_unificado/consensus_sequences.qza

#Clasificado

qiime feature-classifier classify-consensus-blast \
            --i-query "/home/adriano_abb/Qiime/Res_Experim/expCOI/clustered/Consensos_unificado/consensus_sequences.qza" \
            --i-blastdb "/home/adriano_abb/Qiime/V2/NCBI_COI/NCBI_COI_BlastDB.qza" \
            --i-reference-taxonomy "/home/adriano_abb/Qiime/V2/NCBI_COI/NCBI_COI_derep1_taxa.qza" \
			--verbose \
            --p-num-threads 5 \
            --p-perc-identity 0.8 \
            --p-query-cov 0.8 \
            --p-maxaccepts 5 \
            --p-min-consensus 0.51 \
            --o-classification "/home/adriano_abb/Qiime/V2/Trim_NGSpecies/taxonomy.qza" \
            --o-search-results "/home/adriano_abb/Qiime/V2/Trim_NGSpecies/search_results.qza"
			
### EXPORTADO DE LA TABLA DE TAXONOMIA
				qiime tools export \
        --input-path "/home/adriano_abb/Qiime/V2/Trim_NGSpecies/taxonomy.qza" \
        --output-path "/home/adriano_abb/Qiime/V2/Trim_NGSpecies/MaxAc_5/"

### EXPORTADO DE LA TABLA DE TAXONOMIA
				qiime tools export \
        --input-path "/home/adriano_abb/Qiime/V2/Trim_NGSpecies/search_results.qza" \
        --output-path "/home/adriano_abb/Qiime/V2/Trim_NGSpecies/MaxAc_5/"