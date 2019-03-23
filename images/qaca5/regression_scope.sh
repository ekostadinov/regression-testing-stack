#!/usr/bin/env bash
if [ "$#" -ne 2 ]; then
    echo
    echo "This script is used for:"
    echo "    - running the starscope requires on changed files"
    echo "    - logging execution results for further analysis"
    echo
    echo "Use: ./regression_scope.sh <Git Start Tag/CommitHash> <Git End Tag/CommitHash>"
    echo "Notes: "
    echo "   - Place the script in the git repo"
    echo "   - Git pull your repo"
    echo "   - Run `starscope dir-to-index/` to create local DB"
    echo "   - Use the generated file_requires_$gitEnd.txt for Regression scope analysis"
    echo
    exit 1;
fi

echo "---------------------------------------------------------------"
echo "[INFO] =============== Regression scope running ==============="
echo "---------------------------------------------------------------"

gitStart=$1
gitEnd=$2

# FILE LEVEL
# rules & steps of the filtering algorithm
#1 find if our changed_file is the same required by the caller via relative path
#  - keep the root_dir as var
#  - get caller dir
#  - cd to caller dir
#  - check if changed_file exist using the relative path
#  - return to root_dir for next check
#2 ...
#cqsearch -s myproject.db -p 4 -t */shared/abstractions/list-edit* -f -u

ts_prefix='src/'
root=$(pwd)

echo "[INFO] ============= [1/4] COMPILING TYPESCRIPT TO JS  =============="
tsc src/**/*.ts --outDir js/

echo "[INFO] ============= [2/4] CREATING LOCAL DB =============="
starscope js/

echo "[INFO] ============= [3/4] FULL OUTPUT FOR DEBUGING  =============="
changed_files=$(git diff $gitStart $gitEnd --name-only)
for file in $changed_files;do starscope -q requires,$file;done

echo "[INFO] =============== [4/4] AUTOMATIC MAPPING START ==============="
for file in $changed_files;
  do
  filename=$(echo $file | grep -oe "[^/]*$" | cut -d "." -f1)

  echo '>>>'
  echo '>>>'
  echo "Looking for 1st level dependants of changed file -[ $filename ]- FULL path - $file"
  starscope -q requires,$filename | while IFS= read -r line ; do
                                   words=($(echo $line))
                                   called=${words[0]}
                                   caller=${words[2]}
                                   file_dirname=$(dirname $file)
                                   tsjs_file_dirname=$(echo ${file_dirname#"$ts_prefix"})
                                   if [[ $called == *"/"* ]]; then
                                     cd $(dirname $caller)
                                     cd $(dirname $called)
                                     if [[ `pwd` == *"$tsjs_file_dirname"* ]]; then
                                       echo "Caller: $caller"
                                     fi
                                     cd $root
                                   fi
                                 done
done

echo "[INFO] =============== AUTOMATIC MAPPING DONE ==============="
echo "[INFO] =============== FILES TO CLEAN ==============="
echo " - .starscope.db"
echo " - /js"
# FUNCTION LEVEL

#for file in $files;
#  do
#  echo '>>>' & echo "File: $file" & echo '>>>'
#  funcs=$( git diff $gitStart $gitEnd -- $file | grep -woE '([a-zA-Z_{1}][a-zA-Z0-9_]+)[?\(]' | sort --unique | grep -woE '([a-zA-Z_{1}][a-zA-Z0-9_]+)' | grep -Fv -e 'function' -e 'constructor' -e 'super' -e 'require' -e 'map' -e 'then' -e 'catch' -e 'module' -e 'finally' -e 'onSuccess' -e 'onStart' -e 'onError' -e 'to' -e 'toJs' -e 'mergeMap' -e 'setPristine' -e 'setTouched' -e 'combineReducers' -e 'findOne' -e 'textarea' -e 'input'  -e 'dispatch' -e 'push' -e 'Promise' -e 'on' -e 'value' -e 'go' -e 'forEach');

#  for func in $funcs;
#    do
#    echo "Function/Method with name: $func is referenced in files:"
#    references=$(starscope -q calls,$func)
#
#    for ref in $references;
#     do
#     if [[ $ref == *"/"* && $ref == *":"* ]]; then
#       echo "     $ref"
#       #filename=$($file | grep -oe "[^/]*$" | cut -d"." -f1)
#       # requires by full path
#       starscope -q requires,$file
#       # requires by filename only, e.g. same module
#       #starscope -q requires,$filename | grep -F ''
#     fi
#    done
#  done
#done
