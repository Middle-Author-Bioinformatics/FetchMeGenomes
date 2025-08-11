#!/bin/bash
eval "$(/home/ark/miniconda3/bin/conda shell.bash hook)"
conda activate base  # Activate the base environment where `boto3` is installed

exec > >(tee -i /home/ark/MAB/fetchmegenomes/fetchmegenomes_looper.log)
exec 2>&1

eval "$(/home/ark/miniconda3/bin/conda shell.bash hook)"
conda activate base  # Activate the base environment where `boto3` is installed

KEY=$1
ID=$KEY
DIR=/home/ark/MAB/fetchmegenomes/${ID}
OUT=/home/ark/MAB/fetchmegenomes/completed/${ID}-results
mkdir -p ${OUT}


name=$(grep 'Name' ${DIR}/form-data.txt | cut -d ' ' -f2)
email=$(grep 'Email' ${DIR}/form-data.txt | cut -d ' ' -f2)
genus=$(grep 'Genus' ${DIR}/form-data.txt | cut -d ' ' -f2)
species=$(grep 'Species' ${DIR}/form-data.txt | cut -d ' ' -f2)
strain=$(grep 'Strain' ${DIR}/form-data.txt | cut -d ' ' -f2)

# Set PATH to include Conda and script locations
export PATH="/home/ark/miniconda3/bin:/usr/local/bin:/usr/bin:/bin:/home/ark/MAB/bin/FetchMeGenomes:$PATH"
#eval "$(/home/ark/miniconda3/bin/conda shell.bash hook)"
#conda activate fetchmegenomes

if [ $? -ne 0 ]; then
    echo "Error: Failed to activate Conda environment."
    exit 1
fi
sleep 5

# **************************************************************************************************
# **************************************************************************************************
# **************************************************************************************************

if [ -z "$species" ] && [ -z "$strain" ]; then
    python /home/ark/MAB/bin/FetchMeGenomes/ncbi2genomes.py \
        -n /home/ark/databases/ncbi_assembly_info.tsv \
        -g "$genus" \
        -o "${OUT}/ncbi_assembly_info.${genus}.tsv"

elif [ -z "$strain" ]; then
    python /home/ark/MAB/bin/FetchMeGenomes/ncbi2genomes.py \
        -n /home/ark/databases/ncbi_assembly_info.tsv \
        -g "$genus" \
        -s "$species" \
        -o "${OUT}/ncbi_assembly_info.${genus}.${species}.tsv"

elif [ -z "$species" ]; then
    python /home/ark/MAB/bin/FetchMeGenomes/ncbi2genomes.py \
        -n /home/ark/databases/ncbi_assembly_info.tsv \
        -g "$genus" \
        -t "$strain" \
        -o "${OUT}/ncbi_assembly_info.${genus}.${strain}.tsv"

else
    python /home/ark/MAB/bin/FetchMeGenomes/ncbi2genomes.py \
        -n /home/ark/databases/ncbi_assembly_info.tsv \
        -g "$genus" \
        -s "$species" \
        -t "$strain" \
        -o "${OUT}/ncbi_assembly_info.${genus}.${species}.${strain}.tsv"
fi

# **************************************************************************************************
# **************************************************************************************************
# **************************************************************************************************
if [ $? -ne 0 ]; then
    echo "Error: fetchmegenomes failed."
#    conda deactivate
    exit 1
fi
#conda deactivate
#sleep 5

# Archive results
mv /home/ark/MAB/fetchmegenomes/completed/${ID}-results ./${ID}-results
tar -cf ${ID}-results.tar ${ID}-results && gzip ${ID}-results.tar

# Upload results to S3 and generate presigned URL
results_tar="${ID}-results.tar.gz"
s3_key="${ID}-results.tar.gz"
python3 /home/ark/MAB/bin/FetchMeGenomes/push.py --bucket binfo-dump --output_key ${s3_key} --source ${results_tar}
url=$(python3 /home/ark/MAB/bin/FetchMeGenomes/gen_presign_url.py --bucket binfo-dump --key ${s3_key} --expiration 86400)

mv ${ID}-results.tar.gz /home/ark/MAB/fetchmegenomes/completed/${ID}-results.tar.gz
rm -rf ./${ID}-results


# Send email
python3 /home/ark/MAB/bin/FetchMeGenomes/send_email.py \
    --sender ark@midauthorbio.com \
    --recipient ${email} \
    --subject "Your genome assembly info!" \
    --body "Hi ${name},

    The NCBI genome assembly information you requested for the following taxa

    -- Genus: ${genus}
    -- Species: ${species}
    -- Strain: ${strain}

    is available for download using the link below. The link will expire in 24 hours.

    ${url}

    Please reach out to ark@midauthorbio.com if you have any questions.

    Thanks!
    Your friendly neighborhood bioinformatician 🕸️"

#echo python3 /home/ark/MAB/bin/FetchMeGenomes/send_email.py \
#    --sender ark@midauthorbio.com \
#    --recipient ${email} \
#    --subject "Your CIF peptides!" \
#    --body "Hi ${name},
#
#    Your CIF peptide results are available for download using the link below. The link will expire in 24 hours.
#
#    ${url}
#
#    Please reach out to agarber4@asu.com if you have any questions.
#
#    Thanks!
#    Your friendly neighborhood bioinformatician 🕸️"

if [ $? -ne 0 ]; then
    echo "Error: send_email.py failed."
#    conda deactivate
    exit 1
fi

sleep 5

#sudo rm -rf ${DIR}

#conda deactivate
echo "FetchMeGenomes completed successfully."



