correct=0
total=0
while read line
do
  let "total=$total+1"
  echo -en "\e[0K\r$total "
  ./translate-shell/translate -s es -brief "$line"
  read -r answer < /dev/tty
  echo -en "\e[2A"; echo -e "\e[0K\r$total $line"
  say -v Jorge "$line"
  if [ "$answer" == "$line" ]; then
    let "correct=$correct+1"
    echo -en "\e[1A"; echo -e "\e[0K\rcorrect"
  else
    echo -en "\e[1A"; echo -e "\e[0K\rwrong"
  fi
  echo -en "\e[1A"; [ "$answer" == "$line" ] &&  echo -e "\e[0K\r$total $answer ✓" || echo -e "\e[0K\r$total $answer ✗"
done

echo -e "\e[0K\r"
echo -e "\nscore: $correct / $total"
