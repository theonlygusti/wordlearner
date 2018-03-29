correct=0
total=0
source languages.cfg
source voices.cfg
while read line
do
  let "total=$total+1"
  echo -en "$total "
  ./translate-shell/translate "$learning":"$native" -brief "$line"
  read -r answer < /dev/tty
  echo -e "$total $line"
  say -v "${!learning}" "$line"
  if [ "$answer" == "$line" ]; then
    let "correct=$correct+1"
  fi
  [ "$answer" == "$line" ] &&  echo -e "$total $answer ✓" || echo -e "$total $answer ✗"
done

echo -e "\nscore: $correct / $total"
