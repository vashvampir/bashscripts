#!/bin/bash
# Переменные, отвечающие за имена интерфейсов, возможные протоколы и имя выходного файла.
FILE=./generated_rules
IFACES=`ip link | grep -v link | awk '{print $2}' | sed 's/:$//' | tr '\n' ' '`
PROTOS=`cat /etc/protocols | grep -v '^#' | grep -v '^$' | awk '{print $1}' | tr '\n' ', ' | sed 's\,$\\\'`
# Объявление функций
# Поведение по умолчанию, чистим iptables или добавляем правила к существующим
function get_default_policy(){
    touch $FILE
    echo '#!/bin/bash' > $FILE
    whiptail --yesno "Чистить iptables или добавить правила к уже существующим??" --defaultno --yes-button "Чистить" --no-button "Добавить" 0 0 3>&1 1>&2 2>&3
    if [[ $? == 0 ]]; then
	echo 'iptables -F' >> $FILE
    fi
    whiptail --yesno "Будем устанавливать/менять поведение по умолчанию?" --defaultno --yes-button "Да" --no-button "Нет" 0 0 3>&1 1>&2 2>&3
    if [[ $? == 0 ]]; then
	echo "iptables -P INPUT `whiptail --nocancel --menu "Политика цепочки INPUT" 0 0 0 "DROP" "" "ACCEPT" "" 3>&1 1>&2 2>&3`" >> $FILE
	echo "iptables -P OUTPUT `whiptail --nocancel --menu "Политика цепочки OUTPUT" 0 0 0 "DROP" "" "ACCEPT" "" 3>&1 1>&2 2>&3`" >> $FILE
	echo "iptables -P FORWARD `whiptail --nocancel --menu "Политика цепочки FORWARD" 0 0 0 "DROP" "" "ACCEPT" "" 3>&1 1>&2 2>&3`" >> $FILE
    fi
}
# Предопределённые правила
function answer_persets(){

    whiptail --yesno "Добавить часто встречающиеся правила?" --defaultno --yes-button "Да" --no-button "Нет" 0 0 3>&1 1>&2 2>&3
    if [[ $? == 0 ]]; then
	add_persets
    fi

}
function add_persets(){
    whiptail --backtitle "$RULE" --nocancel --separate-output --checklist "Часто встречающиеся правила:" 0 0 0 "1" "Разрешить SSH" off "2" "Разрешить RDP" off "3" "Разрешить VNC" off "4" "Разрешить FTP" off "5" "Разрешить HTTP/HTTPS" off "6" "Разрешить OpenVPN" off "7" "Разрешить Ipsec/L2TP" off "8" "Разрешить DNS" off "9" "Разрешить Squid" off "10" "Разрешить POP3/SSL" off "11" "Разрешить IMAP/SSL" off "12" "Разрешить SMTP/SSL" off "13" "Разрешить ping" off "14" "Разрешить NTP" off 2>persets_file
	if [ -s ./persets_file ]; then
	    while read choice; do
		case $choice in
		    1) echo "iptables -A INPUT -p tcp --dport 22 -j ACCEPT" >> $FILE;;
		    2) echo "iptables -A INPUT -p tcp --dport 3389 -j ACCEPT" >> $FILE;;
		    3) echo "iptables -A INPUT -p tcp --dport 5900 -j ACCEPT" >> $FILE;;
		    4) echo "iptables -A INPUT -p tcp --dport 21 -j ACCEPT" >> $FILE;;
		    5) echo -e "iptables -A INPUT -p tcp --dport 80 -j ACCEPT\niptables -A INPUT -p tcp --dport 443 -j ACCEPT" >> $FILE;;
		    6) echo "iptables -A INPUT -p udp --dport 1194 -j ACCEPT" >> $FILE;;
		    7) echo -e "iptables -A INPUT -p udp --dport 500 -j ACCEPT\niptables -A INPUT -p udp --dport 4500 -j ACCEPT" >> $FILE;;
		    8) echo -e "iptables -A INPUT -p udp --dport 53 -j ACCEPT\niptables -A INPUT -p tcp --dport 53 -j ACCEPT" >> $FILE;;
		    9) echo "iptables -A INPUT -p tcp --dport 3128 -j ACCEPT" >> $FILE;;
		    10) echo "iptables -A INPUT -p tcp --dport 995 -j ACCEPT" >> $FILE;;
		    11) echo "iptables -A INPUT -p tcp --dport 993 -j ACCEPT" >> $FILE;;
		    12) echo "iptables -A INPUT -p tcp --dport 465 -j ACCEPT" >> $FILE;;
		    13) echo -e "iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT\niptables -A INPUT -p icmp --icmp-type 0 -j ACCEPT\niptables -A OUTPUT -p icmp --icmp-type 0 -j ACCEPT\niptables -A OUTPUT -p icmp --icmp-type 8 -j ACCEPT" >> $FILE;;
		    14) echo "iptables -A INPUT -p udp --dport 123 -j ACCEPT" >> $FILE;;
		    
		esac
	    done < persets_file
	fi
	rm -f persets_file
}
# В цикле задаём вопрос, добавляем правило или нет
function add_rule_question(){
    CONT=0
    while [[ $CONT == 0 ]]; do 
	whiptail --yesno "Добавить правило?" --yes-button "Да" --no-button "Нет" 0 0 3>&1 1>&2 2>&3
	if [[ $? == 0 ]]; then
	    make_rule
	else
	    CONT=1
	fi
    done
}
# Тело генератора правил
function make_rule(){
    RULE="iptables -A `whiptail --backtitle "$RULE" --nocancel --menu "Выбор цепочки" 0 0 0 "INPUT" "Входящий трафик" "OUTPUT" "Исходящий трафик" "FORWARD" "Проходящий трафик" 3>&1 1>&2 2>&3`"
    # Выбор входящего интерфейса
    function inp_iface(){
	IFACE=$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите имя входящего интерфейса. Возможные варианты: $IFACES" 0 0 3>&1 1>&2 2>&3)
	if [ -z $IFACE ]; then
	    :
	else
	    RULE=$RULE" -i $IFACE"
	fi
    }
    # Выбор исходящего интерфейса
    function out_iface(){
	IFACE=$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите имя исходящего интерфейса. Возможные варианты: $IFACES" 0 0 3>&1 1>&2 2>&3)
	if [ -z $IFACE ]; then
	    :
	else
	    RULE=$RULE" -o $IFACE"
	fi
    }
    # Выбор протоколов и ввод портов
    function proto(){
	function dst_port(){
	    dport=`whiptail --backtitle "$RULE" --nocancel --inputbox "Введите номер destination порта, или диапозон портов через \":\" (например 22:28)" 0 0 3>&1 1>&2 2>&3`
	    if [ -z $dport ]; then
		:
	    else
		RULE=$RULE" --dport $dport"
	    fi
	}
	function src_port(){
	    sport=`whiptail --backtitle "$RULE" --nocancel --inputbox "Введите номер source порта, или диапозон портов через \":\" (например 22:28)" 0 0 3>&1 1>&2 2>&3`
	    if [ -z $sport ]; then
		:
	    else
		RULE=$RULE" --sport $sport"
	    fi
	}
	case $(whiptail --backtitle "$RULE" --nocancel --menu "Выбор протокола" 0 0 0 "1" "TCP" "2" "UDP" "3" "ICMP" "4" "Ввести вручную" 3>&1 1>&2 2>&3) in
	    1) RULE=$RULE" -p tcp"; src_port; dst_port;;
	    2) RULE=$RULE" -p udp"; src_port; dst_port;;
	    3) RULE=$RULE" -p icmp";;
	    4) RULE=$RULE" -p `whiptail --backtitle "$RULE" --nocancel --inputbox "Введите название протокола. Возможные варианты для системы:\n$PROTOS" 0 0 3>&1 1>&2 2>&3`" ;;
	esac
    }
    # Ввод IP источника
    function source_ip(){
	s_ip=$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите IP адрес источника. Через '/' можно указать префикс." 0 0 3>&1 1>&2 2>&3)
	if [ -z $s_ip ]; then
	    :
	else
	    RULE=$RULE" -s $s_ip"
	fi
    }
    # Ввод IP назначения
    function dest_ip(){
	d_ip=$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите IP адрес назначения. Через '/' можно указать префикс." 0 0 3>&1 1>&2 2>&3)
	if [ -z $d_ip ]; then
	    :
	else
	    RULE=$RULE" -d $d_ip"
	fi
    }
    # Выбор статуса соединения
    function conntrack(){
	whiptail --backtitle "$RULE" --nocancel --separate-output --checklist "Статус соединения:" 0 0 0 "ESTABLISHED" "" off "RELATED" "" off "NEW" "" off "INVALID" "" off 2>conntrack_file
	if [ -s ./conntrack_file ]; then
	    tmp_choice=""
	    i=1
	    while read choice; do
		if [[ i == 1 ]]; then
		    tmp_choice=$choiceanswer_persets
		else
		    tmp_choice=$tmp_choice",$choice"
		fi
		(( i++ ))
	    done < conntrack_file
	    echo $tmp_choice > conntrack_file
	    sed -e 's/^.//' conntrack_file > conntrack_file1
	    RULE=$RULE" -m conntrack --ctstate $(cat ./conntrack_file1)"
	    rm -f conntrack_file1
	fi
	rm -f conntrack_file
    }
    # Выбор дней недели и ввод времени
    function ip_time(){
	whiptail --backtitle "$RULE" --nocancel --separate-output --checklist "Дни недели:" 0 0 0 "Mon" "" off "Tue" "" off "Wed" "" off "Thu" "" off "Fri" "" off "Sat" "" off "San" "" off 2>weekdays
	if [ -s ./weekdays ]; then
	    tmp_choice=""
	    i=1
	    while read choice; do
		if [[ i == 1 ]]; then
		    tmp_choice=$choice
		else
		    tmp_choice=$tmp_choice",$choice"
		fi
		(( i++ ))
	    done < weekdays
	    echo $tmp_choice > weekdays
	    sed -e 's/^.//' weekdays > weekdays1
	    RULE=$RULE" -m time --weekdays $(cat ./weekdays1)"
	    rm -f weekdays1
	fi
	rm -f weekdays
	time_start=$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите время начала действия правила в формате ЧЧ:ММ:СС" 0 0 3>&1 1>&2 2>&3)
	if [ -z $time_start ]; then
	    :
	else
	    if [[ $RULE =~ "-m time" ]] ; then :; else RULE=$RULE"-m time"; fi
	    RULE=$RULE" --timestart $time_start"
	fi
	time_stop=$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите время окончания действия правила в формате ЧЧ:ММ:СС" 0 0 3>&1 1>&2 2>&3)
	if [ -z $time_stop ]; then
	    :
	else
	    if [[ $RULE =~ "-m time" ]] ; then :; else RULE=$RULE" -m time"; fi
	    RULE=$RULE" --timestop $time_stop"
	fi	
    }
    # Выбор сообщения, с которым откланяем пакет
    function reject_with(){
	RULE=$RULE" --reject-with "$(whiptail --backtitle "$RULE" --nocancel --menu "С каким сообщением откланяем пакет?" 0 0 0 "icmp-port-unreachable" "" "icmp-host-unreachable" "" "icmp-net-unreachable" "" "icmp-proto-unreahable" "" "icmp-net-prohibited" "" "icmp-host-prohibited" "" 3>&1 1>&2 2>&3)
    }
    # Настройки логирования
    function logging(){
	# Выбор уровня протоколирования
	function log_level(){
	RULE=$RULE" --log-level "$(whiptail --backtitle "$RULE" --nocancel --menu "Какой будет уровень протоколирования?" 0 0 0 "debug" "Отладочое сообщение" "info" "Информационное сообшение" "notice" "Важное уведомление" "warning" "Предупреждение" "error" "Ошибка" "crit" "Критическое событие" "alert" "Необходимо срочное вмешательство" "emerg" "Система не работоспособна" 3>&1 1>&2 2>&3)
	}
	# Ввод префикса логов
	function log_prefix(){
	log_prefix_input=`whiptail --backtitle "$RULE" --nocancel --inputbox "Введите префикс (максимум 29 символов):" 0 0 3>&1 1>&2 2>&3`
	if [ -z "$log_prefix_input" ]; then
	    :
	else
	    RULE=$RULE" --log-prefix \"$log_prefix_input\""
	fi
	}
	# Выбор дополнительных опций логирования
	whiptail --backtitle "$RULE" --nocancel --separate-output --checklist "Дополнительные опции логирования" 0 0 0 "1" "Уровень протоколирования" off "2" "Префикс" off "3" "Протоколирование ISN" off "4" "Протоколирование TCP-опций" off "5" "Протоколирование IP-опций" off 2>logging_file
	if [ -s ./logging_file ]; then
	    while read choice; do
		case $choice in
		    1) log_level;;
		    2) log_prefix;;
		    3) RULE=$RULE" --log-tcp-sequences";;
		    4) RULE=$RULE" --log-tcp-options";;
		    5) RULE=$RULE" --log-ip-options";;
		esac
	    done < logging_file
	fi
	rm -f logging_file
    }
    # Настройки TTL
    function ttl(){
	# Выбор опций TTL
	choice=`whiptail --backtitle "$RULE" --nocancel --menu "Что делаем с TTL?" 0 0 0 "1" "Устанавливаем значение" "2" "Увеличиваем" "3" "Уменьшаем" 3>&1 1>&2 2>&3`
	case $choice in
	    1) RULE=$RULE" --ttl-set "$(whiptail --backtitle "$RULE" --nocancel --inputbox "Введите нужный TTL:" 0 0 3>&1 1>&2 2>&3);;
	    2) RULE=$RULE" --ttl-inc "$(whiptail --backtitle "$RULE" --nocancel --inputbox "На сколько увеличиваем TTL?" 0 0 3>&1 1>&2 2>&3);;
	    3) RULE=$RULE" --ttl-dec "$(whiptail --backtitle "$RULE" --nocancel --inputbox "На сколько уменьшаем TTL?" 0 0 3>&1 1>&2 2>&3);;
	esac
    }
    # Вопрос о том, что будет содержать генерируемое правило
    whiptail --backtitle "$RULE" --nocancel --separate-output --checklist "Что будет содержать правило?" 0 0 0 "1" "Входящий интерфейс" off "2" "Исходящий интерфейс" off "3" "Протокол/порт" off "4" "IP источника" off "5" "IP назначения" off "6" "Статус соединения" off "7" "Время" off 2>temp_file
    while read choice; do
	case $choice in
	    1) inp_iface;;
	    2) out_iface;;
	    3) proto;;
	    4) source_ip;;
	    5) dest_ip;;
	    6) conntrack;;
	    7) ip_time;;
	esac
    done < temp_file
    rm -f temp_file
    RULE=$RULE" -j "$(whiptail --backtitle "$RULE" --nocancel --menu "Выбор действия" 0 0 0 "ACCEPT" "" "DROP" "" "REJECT" "" "LOG" "" "TTL" "" 3>&1 1>&2 2>&3)
    if [[ $RULE =~ "-j REJECT" ]]; then reject_with; fi
    if [[ $RULE =~ "-j LOG" ]]; then logging; fi
    if [[ $RULE =~ "-j TTL" ]]; then ttl; fi
    echo $RULE >> $FILE
}
# Тут заканчиваются функции
get_default_policy
answer_persets
add_rule_question
chmod +x $FILE
whiptail --yesno "В $FILE записано `wc -l $FILE | awk '{print $1}'` строк(и) и он помечен как исполняемый.\nХотите посмотреть его содержимое?" --yes-button "Да" --no-button "Нет" 0 0 3>&1 1>&2 2>&3
if [[ $? == 0 ]]; then whiptail --title "Содержимое $FILE" --msgbox "`cat $FILE`" 0 0 3>&1 1>&2 2>&3; fi
