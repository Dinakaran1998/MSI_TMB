import gzip
import sys

vcf_file = sys.argv[1] if len(sys.argv) > 1 else "tumor.vcf.gz"

count = 0
with gzip.open(vcf_file, "rt") as f:
    for line in f:
        if line.startswith("#"): continue
        fields = line.split("\t")
        if "PASS" in fields[6]:
            count += 1

print("Total somatic variants:", count)
print("TMB (mutations/Mb):", count / 38)  # 38 Mb exome
