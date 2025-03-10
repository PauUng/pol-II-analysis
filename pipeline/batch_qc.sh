#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 -i <input_folder> -o <output_folder>"
    echo "[-d <docker_image_path>] [-l <slurm_log_folder>] [-L]"
    exit 1
}

script_directory="$(cd "$(dirname "$0")" && pwd)"
repository_path="$(dirname "$script_directory")"

# Variables to hold arguments
input_folder=""
output_folder=""
run_locally=false
docker_image_path="$repository_path"/docker_images/bioinfo_tools.tar
slurm_log_folder="$output_folder"/slurm_logs

# Parse command line arguments
while getopts ":i:o:d:l:L" opt; do
    case ${opt} in
        i )
            input_folder=$OPTARG
            ;;
        o )
            output_folder=$OPTARG
            ;;
        d )
            docker_image_path=$OPTARG
            ;;
        l )
            slurm_log_folder=$OPTARG
            ;;
        L )
            run_locally=true
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done

# Check if mandatory arguments are provided
if [ -z "$input_folder" ] || [ -z "$output_folder" ]; then
    echo "Error: Missing mandatory arguments"
    usage
fi

# Create output folder if it doesn't exist
mkdir -p "$output_folder"

# Extract sample names by identifying unique prefixes before _R1 or _R2
find "$input_folder" -type f -name "*_R[12]*.fastq.gz" | \
    sed -E 's/_(R1|R2).*//' | sort | uniq | while read sample_path; do
    sample_name=$(basename "$sample_path")
    
    if [ "$run_locally" = true ]; then
        echo "Processing sample $sample_name"
        sh "$repository_path"/scripts/fastqc.sh -i "$input_folder" -o "$output_folder"/"$sample_name" \
        -d "$docker_image_path"
    else
        echo "Submitting sample $sample_name"
        sbatch --output="$slurm_log_folder"/%j_%x.log --error="$slurm_log_folder"/%j_%x.err \
        "$repository_path"/scripts/fastqc.sh -i "$input_folder" -o "$output_folder"/"$sample_name" \
        -d "$docker_image_path"
    fi
done
