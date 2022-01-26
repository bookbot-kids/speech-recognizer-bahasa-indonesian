#! /bin/zsh

# we need to do this otherwise pyinstaller-compiled python binaries do not know how to interpret text on STDIN
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"

ngram=1
lm_suffix="lm"
input=$1
odir=$(dirname $input)
am=$2
language=$3
aligner_path=$4

rm -rf $odir/graph $odir/lang $odir/lang_prepped /tmp/lang_tmp $odir/lm $odir/lm_out $odir/dict

mkdir -p $odir/tmp $odir/lang $odir/dict $odir/lm $odir/graph

cd kaldi/bin

cp -R ../$language/dict/* $odir/dict

# split the corpus input into words.txt
tr -cs 'a-zA-Z0-9\-' '\n' < $input | sed "s/^-$//g" | sort | uniq | awk '{printf "%s\t%s\n",$0,NR}' > $odir/lang/words.txt

declare -A lexicon

while IFS=' ' read k; do 
    lexicon[$k]=1;
done < <(cut -f1 ../$language/dict/lexicon.txt)

# see which words aren't in the lexicon
cat $odir/lang/words.txt | cut -f1 | while read line; do 
    if [ -z "${lexicon[$line]}" ]; then
        echo $line;
    fi
done > $odir/dict/requires_lexicon.txt

# create the lexicon
cat $odir/lang/words.txt | cut -f1 | sed -E "/(<|#)/d" > $odir/lang/words_cleaned.txt

create_lexicon $language $odir/dict/requires_lexicon.txt $odir/dict/lexicon_added.txt "$aligner_path"
cat $odir/dict/lexicon_added.txt >> $odir/dict/lexicon.txt

rm $odir/lang/G.fst

./utils/prepare_lang.sh $odir/dict "<UNK>" /tmp/lang_tmp $odir/lang_prepped;

# create the 0-gram LM
ngrams=$(cat "$odir/lang_prepped/words.txt" | cut -d' ' -f1 | sed -E "/<eps>|#0/d" | awk '{ if(length > 1) printf "-1.0 %s\n",$0; }')
ngc=$(echo "$ngrams" | wc -l | cut -f1)
echo "\\data\\ 
ngram 1=$((ngc+2))

\1-grams:
${ngrams}

\\\end\ 
" > $odir/lm/lm.arpa

gzip -f $odir/lm/lm.arpa

./utils/format_lm.sh $odir/lang_prepped $odir/lm/lm.arpa $odir/dict/lexicon.txt $odir/lm_out

./utils/mkgraph_lookahead.sh --self-loop-scale 1.0  $odir/lm_out $am $odir/graph

#farcompilestrings --fst_type=compact --symbols=$odir/graph/words.txt --keep_symbols $input | \
# ngramcount --order=2 | ngrammake | \
# fstconvert --fst_type=ngram > $odir/graph/Gr.fst || exit -1;
 
# rm -f $odir/graph/HCLG.fst

exit 0;


