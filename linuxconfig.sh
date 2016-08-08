#!/bin/bash
# Script d'installation et de configuration pour Debian
#
# Sources :
# Très inspiré de LXCONFIG de Laurent Bisson
# http://maclol.inetlab.fr/lxconfig-2/
#
# Adapté par et pour Antoine RENIER - 27/07/2016

#v="1"					# Version
noyau=$(uname -sr)			# noyau linux
today=$(date "+%d/%m/%Y")	# Date

# Définition des couleurs
vertclair='\e[32m'
neutre='\e[0;m'
blanc='\e[37m'
cyanclair='\e[36m'
rouge='\e[31m'

# Verifie que les dossiers dans /opt sont présents
if [ ! -d "/opt/linuxconfig" ]
then
	mkdir /opt/linuxconfig
	mkdir /opt/linuxconfig/conf.bak
	mkdir /opt/linuxconfig/datas
	mkdir /opt/linuxconfig/tmp
fi

############################
# Definition des fonctions
##########################

####
# Gestion de l'affichage
# 
# Ecrire une chaîne de caractères
function writeString { 			# ("couleur", "espacement", "texte")
	printf "$1%-$2s" "$3"
}
# Colonne numéro
function colNum {			# ("texte")
	writeString "${cyanclair}" "4" "$1"
}
# Colonne rôle
function colRole {			# ("texte")
	writeString "${blanc}" "25" "$1"
}
# Colonne install
function colInstall {			# ("texte")
	cinstall="${blanc}"
	if [ "$1" = "OK" ]; then
		cinstall="${vertclair}"
	fi
	writeString "${cinstall}" "10" "$1"
}
# Colonne status
function colStatus {			# ("texte")
	cstatus="${blanc}"
	if [ "$1" = "STOP" ]; then
		cstatus="${rouge}"
		else if [ "$1" = "OK" ]; then
			cstatus="${vertclair}"
		fi
	fi
	writeString "${cstatus}" "10" "$1"
}
# Colonne fin
function colFin {			# ("texte")
	if [ -n "$1" ]
		then
		writeString "| ${blanc}" "50" "$1"
	fi
}
# Ecrire toute la ligne
	function writeLinerInterface {		# (Num, "Role", "Install", "Status", "Fin de ligne")
		colNum "$1"
		colRole "$2"
		colInstall "$3"
		colStatus "$4"
		colFin "$5"
		printf "\n" ""
	}
####

# Vérification des paquets ("paquet1 paquet2 etc.")
function checkPackages
{
	local paquetsCheck;local paquet;local paquetOn;local dateOp;
	paquetsCheck=$1

	for paquet in $paquetsCheck
	do
		paquetOn=$( dpkg -l | grep "ii  $paquet " | cut -d" " -f3 )
		if [ -z "$paquetOn" ]
  		then	
			echo -e "Paquet $paquet manquant...Installation...\n"
			apt-get -y install $paquet > /dev/null
  		fi 
	done
}

# Fonction de récupération des données Réseau
function getNetworkDatas
{
	# Interface graphique ou non
	gui_on=$( dpkg -l | grep "ii  network-manager " | cut -d" " -f3 )

	# Fichier réseau suivant type interface
	[ ! -z $gui_on ] && netFile="/etc/NetworkManager/system-connections" || netFile="/etc/network/interfaces"

	# Récupère date de modification des fichiers
	[ -e "$netFile" ] 				&& dateNetFile=$( stat -c%Z "$netFile" )
	[ -e "/opt/linuxconfig/netDatabank" ] && dateNetData=$( stat -c%Z "/opt/linuxconfig/netDatabank" ) || dateNetData=0

	if [ "$dateNetFile" -gt "$dateNetData" ]
	then
		noInt=""
		interFaces=$( ifconfig | egrep '^[^ ]' | awk '{print $1}' | sed '/lo/d' )
		if [ -f "/opt/linuxconfig/netDatabank" ];then rm /opt/linuxconfig/netDatabank;fi
		for interface in $interFaces
		do
			((noInt ++))
			int["$noInt"]=$( ifconfig $interface )
			if [ $? -eq 0 ]
			then
				ip=$( echo ${int["$noInt"]} | cut -d":" -f8 | cut -d" " -f1)
				broad=$( echo ${int["$noInt"]} | cut -d":" -f9 | cut -d" " -f1)
				masque=$( echo ${int["$noInt"]} | cut -d":" -f10 | cut -d" " -f1)
				intface=$( echo ${int["$noInt"]} | cut -d":" -f2 | cut -d" " -f1)
				addrmac=$( echo ${int["$noInt"]} | cut -d" " -f5)
				echo "$interface;$ip;$intface;$addrmac" >> /opt/linuxconfig/netDatabank
			fi
		done
	fi
}

# Etat dns
function getDns
{
	etat_dnsserver=$( dpkg -l | grep '^i' | grep ' bind9 ' )
	if [[ $etat_dnsserver = *"ii"* ]]
		then
		dnsserver="OK"
		couleurdns="${vertclair}"
		service_dns=$( service bind9 status )
			if [ $? -eq 0 ]
			then
			sdns="OK"
			cdns=${vertclair}
			else
			sdns="STOP"
			cdns=${rouge}
			fi	
		else
		dnsserver="non"
		couleurdns="${neutre}"
		sdns="---"
	fi
}

# Etat & service DHCP
function getDhcp
{
	etat_dhcpserver=$( dpkg -l | grep '^i' | grep 'isc-dhcp-server' )
	if [[ $etat_dhcpserver = *"ii"* ]]
		then
		dhcpserver="OK"
		couleurdhcp=${vertclair}
			if [ ! -f "/opt/linuxconfig/conf.bak/dhcpd.conf.bak" ]
			then
			cp /etc/dhcp/dhcpd.conf /opt/linuxconfig/conf.bak/dhcpd.conf.bak
			fi
			service_dhcp=$( service isc-dhcp-server status )
			if [ $? -eq 0 ]
				then
				sdhcp="OK"
				cdhcp=${vertclair}
				else
				sdhcp="STOP"
				cdhcp=${rouge}
			fi
		else
		dhcpserver="non"
		couleurdhcp=${neutre}
		sdhcp="---"
	fi
}

# Etat samba
function getSamba
{
	etat_sambaserver=$( dpkg -l | grep '^i' | grep 'samba' )
	if [[ $etat_sambaserver = *"ii"* ]]
		then
		sambaserver="OK"
		couleursamba="${vertclair}"
			if [ ! -f "/opt/linuxconfig/conf.bak/smb.conf.bak" ]
			then
			cp /etc/samba/smb.conf /opt/linuxconfig/conf.bak/smb.conf.bak
			fi
			service_samba=$( /etc/init.d/samba status )
			if [ $? -eq 0 ]
				then
				ssamba="OK"
				csamba=${vertclair}
				else
				ssamba="STOP"
				csamba=${rouge}
			fi
		else
		sambaserver="non"
		couleursamba="${neutre}"
		ssamba="---"
	fi
}

# Etat NFS
function getNfs
{
	etat_nfsserver=$( dpkg -l | grep '^i' | grep 'nfs-kernel-server' )
	if [[ $etat_nfsserver = *"ii"* ]]
		then
		nfsserver="OK"
		couleurnfs="${vertclair}"
			if [ ! -f "/opt/linuxconfig/conf.bak/exports.bak" ]
			then
			cp /etc/exports /opt/linuxconfig/conf.bak/exports.bak
			fi
			service_nfs=$( service nfs-kernel-server status > /dev/null )
			if [ $? -eq 0 ]
			then
				snfs="OK"
				cnfs=${vertclair}
				else
				snfs="STOP"
				cnfs=${rouge}
			fi
		else
		nfsserver="non"
		couleurnfs="${neutre}"
		snfs="---"
	fi
}

# Etat SSH
function getSsh
{
	etat_sshserver=$( dpkg -l | grep '^i' | grep 'openssh-server' )
	if [[ $etat_sshserver = *"ii"* ]]
	then
		sshserver="OK"
		couleurssh="${vertclair}"
		service_ssh=$( service ssh status )
		if [ $? -eq 0 ]
			then
			sssh="OK"
			cssh=${vertclair}
			else
			sssh="STOP"
			cssh=${rouge}
		fi
	else
		sshserver="non"
		couleurssh="${neutre}"
		sssh="---"
	fi
}

# Etat ftp
function getFtp
{
	etat_ftpserver=$( dpkg -l | grep '^i' | grep 'proftpd' )
	if [[ $etat_ftpserver = *"ii"* ]]
		then
		ftpserver="OK"
		couleurftp="${vertclair}"
			if [ ! -f "/opt/linuxconfig/conf.bak/proftpd.conf.bak" ]
			then
			cp /etc/proftpd/proftpd.conf /opt/linuxconfig/conf.bak/proftpd.conf.bak
			fi
			service_ftp=$( service proftpd status )
			if [ $? -eq 0 ]
			then
			sftp="OK"
			cftp=${vertclair}
			else
			sftp="STOP"
			cftp=${rouge}
			fi
		else
		ftpserver="non"
		couleurftp="${neutre}"
		sftp="---"
	fi
}

# Etat ntp server
function getNtp
{
	etat_ntpserver=$( dpkg -l | grep '^i' | grep 'ntp' )
	if [[ $etat_ntpserver = *"ii"* ]]
	then
		ntpserver="OK"
		couleurntp="${vertclair}"
		service_ntp=$( service ntp status )
		if [ $? -eq 0 ]
		then
			sntp="OK"
			cntp=${vertclair}
		else
			sntp="STOP"
			cntp=${rouge}
		fi
	else
		ntpserver="non"
		couleurntp="${neutre}"
		sntp="---"
	fi
}

# Etat serveur web
function getWeb
{
	etat_apacheserver=$( dpkg -l | grep '^ii' | grep ' apache2 ' | cut -d" " -f3 )
	etat_lighttpd=$( dpkg -l | grep '^ii' | grep 'lighttpd'  | cut -d" " -f3 )
	etat_nginx=$( dpkg -l | grep 'ii  nginx '  | cut -d" " -f3 )
	if [ -z $etat_lighttpd ]
	then
		if [ ! -z $etat_apacheserver ]
		then 
		etat_webserver=$( echo $etat_apacheserver )
		fi	
		if [ ! -z $etat_nginx ]
		then
		etat_webserver=$( echo $etat_nginx )
		fi
	else
	etat_webserver=$( echo $etat_lighttpd )
	fi
	webserver=$( echo $etat_webserver)

	if [ ! -z $webserver ]
	then
		couleurweb="${vertclair}"
		service_web=$( service "$etat_webserver" status )
		if [ $? -eq 0 ]
		then
			sweb="OK"
			cweb=${vertclair}
		else
			sweb="STOP"
			cweb=${rouge}
		fi
	else
	webserver="non"
	couleurweb="${neutre}"
	sweb="---"
	fi
}

# Etat Php
function getPhp
{
	etat_php=$( dpkg -l | grep "^ii  php5 " | cut -d" " -f3 )
	if [[ $etat_php = *"php5"* ]]
	then
		phpserver="OK"
		couleurphp="${vertclair}"
	else
		phpserver="non"
		couleurphp="${neutre}"
	fi

	if [ -z $etat_php ]
	then
	etat_php=$( dpkg -l | grep "^ii  php5-fpm" | cut -d" " -f3 )
		if [[ $etat_php = "php5-fpm" ]]
		then
			phpserver="OK"
			couleurphp="${vertclair}"
			else
			phpserver="non"
			couleurphp="${neutre}"
		fi
	fi
}

# Etat Mysql
function getMysql
{
	# Etat mysql
	etat_mysqlserver=$( dpkg -l | grep '^i' | grep ' mysql-server ' )
	if [[ $etat_mysqlserver = *"ii"* ]]
	then
	mysqlserver="OK"
	couleurmysql="${vertclair}"
	service_mysql=$( service mysql status )
		if [ $? -eq 0 ]
		then
		smysql="OK"
		cmysql=${vertclair}
		else
		smysql="STOP"
		cmysql=${rouge}
		fi	
	else
	mysqlserver="non"
	couleurmysql="${neutre}"
	smysql="---"
	fi
}

# Etat imprimante
function getPrinter
{
	etat_imp=$( dpkg -l | grep '^i' | grep 'task-print-server' )
	if [[ $etat_imp = *"ii"* ]]
		then
		cupsserver="OK"
		couleurcups="${vertclair}"
		service_cups=$( lpstat -r )
		if [ $? -eq 0 ]
		then
			scups="OK"
			ccups=${vertclair}
			else
			scups="ND"
			ccups=${neutre}
		fi
		else
		cupsserver="non"
		couleurcups="${neutre}"
		scups="---"
	fi
}

# Etat role radius
function getRadius
{
	etat_radiusserver=$( dpkg -l | grep '^i' | grep ' freeradius ' )
	if [[ $etat_radiusserver = *"ii"* ]]
		then
		radiusserver="OK"
		couleurradius="${vertclair}"
		service_radius=$( service freeradius status )
		if [ $? -eq 0 ]
		then
			sradius="OK"
			cradius=${vertclair}
			else
			sradius="ND"
			cradius=${neutre}
		fi
		else
		radiusserver="non"
		couleurradius="${neutre}"
		sradius="---"
	fi
}

# Etat haproxy
function getHaproxy
{
	etat_haproxy=$( dpkg -l | grep '^ii  haproxy' | cut -d" " -f1)
	if [[ $etat_haproxy = *"ii"* ]]
		then
		haproxyserver="OK"
		couleurhaproxy="${vertclair}"
		service_haproxy=$( service haproxy status )
		if [ $? -eq 0 ]
		then
			shaproxy="OK"
			chaproxy=${vertclair}
			else
			shaproxy="STOP"
			chaproxy=${rouge}
		fi
		else
		haproxyserver="non"
		couleurhaproxy="${neutre}"
		shaproxy="---"
	fi
}

# Etat mirroir
function getMirroir
{
	etat_mirroirserver=$( dpkg -l | grep '^i' | grep 'apt-mirror' )
	if [[ $etat_mirroirserver = *"ii"* ]]
		then
		mirroirserver="OK"
		couleurmirroir="${vertclair}"
		if [ -h /var/www/deb ] && [ -h /var/www/secudebian ]
		then
			smirroir="OK"
			cmirroir=${vertclair}
			else
			smirroir="STOP"
			cmirroir=${rouge}
		fi
		else
		mirroirserver="non"
		couleurmirroir="${neutre}"
		smirroir="---"
	fi
}

# Etat role routeur
function getRouter
{
	etat_routeur=$( sed -n "/^#net.ipv4.ip_forward=1/p" /etc/sysctl.conf )
	if [ -z $etat_routeur ]
		then
		role_routeur=$( echo "Actif" )
		couleurrouteur="${vertclair}"
		else
		role_routeur=$( echo "Inactif" )
		couleurrouteur="${neutre}"
	fi
}

# Etat de tous les services (pour page principale)
function getStates 
{
	getDns;getDhcp;getSamba;getNfs;getSsh;getFtp;getNtp;getWeb
	getPrinter;getRadius;getHaproxy;getMirroir;getRouter
}

# Configuration de cron-apt
function cronaptConfig {
	local FILE;

	# Fichier de conf
	FILE="/etc/cron-apt/config"

	if ! [ -f /etc/cron-apt/action.d/5-install ]; then
		grep security /etc/apt/sources.list > /etc/apt/security.sources.list

		echo "Configuration de cron-apt..."
		echo "APTCOMMAND=/usr/bin/apt-get" >> $FILE
		echo "grep security /etc/apt/sources.list > /etc/apt/security.sources.list" >> $FILE
		echo "MAILTO=\""$MAIL"\"" >> $FILE
		echo "MAILON=\"upgrade\"" >> $FILE
		# Ajout de l'installation automatique
		echo "dist-upgrade -y -o APT::Get::Show-Upgraded=true" > /etc/cron-apt/action.d/5-install
	else
		echo "Le paquet cron-apt est déjà configuré."
	fi
}

# Configuration de base de Fail2ban
function fail2banConfigBase {
	if ! [ -f /etc/fail2ban/jail.conf.bkp ]; then
		echo "Configuration de base de fail2ban..."
		cp -a /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bkp

		# Envoi de mail
		sed -i 's/destemail = root@localhost/destemail = '$MAIL'/g' /etc/fail2ban/jail.conf
		sed -i 's/sender = fail2ban@localhost/sender = fail2ban@'$(hostname)'/g' /etc/fail2ban/jail.conf
		sed -i 's/action = %(action_)s/action = %(action_mw)s/g' /etc/fail2ban/jail.conf
		# Sécurisation du SSH
		LINENUMBER=$(grep -n 'ssh-ddos' /etc/fail2ban/jail.conf | awk -F':' '{ print $1 }')
		LINENUMBER=$(($LINENUMBER+2))
		sed -i ''$LINENUMBER' s/false/true/' /etc/fail2ban/jail.conf

		service fail2ban restart
	else
		echo "Le paquet fail2ban est déjà configuré."
	fi
}

# Confifuration de logwatch
function logwatchConfig {
	if ! [ -f /root/backups/00logwatch.bkp ]; then
		echo "Configuration de logwatch..."
		mkdir /root/backups
		cp -a /etc/cron.daily/00logwatch /root/backups/00logwatch.bkp
		sed -i 's/logwatch --output mail/logwatch --mailto '$MAIL' --detail high/g' /etc/cron.daily/00logwatch
	else
		echo "Le paquet logwatch est déjà configuré."
	fi
}

# Configuration de Oh-My-Zsh
function zshConfig {
	echo -e "Personnalisation de Zsh"
	sed -i 's/# ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/g' /root/.zshrc
	sed -i 's/plugins=(git)/plugins=(z)/g' /root/.zshrc
	# Theme agnoster
	sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/g' /root/.zshrc
	echo -e "Changer la police du terminal en \"Meslo LG M\" et les coleurs en \"Solarized dark\"."
	read -p "Appuyez sur entrée pour continuer..."
}

# Configuration de VIM
function vimConfig {
	if ! [ -f /etc/vim/vimrc ]; then
		echo "Vim n'est pas installé."
		exit 1
	fi

	checkPackages "curl git"

	# Emplacement du fichier de configuration
	local FILE;
	FILE="/etc/vim/vimrc"

	# Backup du fichier de configuration s'il n'existe pas
	if ! [ -f $FILE.bkp ]; then

		cp -a $FILE $FILE.bkp
		echo "Creation de "$FILE".bkp"

		# Install Pathogen pour installer Solarized
		echo "Installation de Pathogen..."
		mkdir -p ~/.vim/autoload ~/.vim/bundle && \
		curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
		echo "" >> $FILE
		echo "\" Pathogen" >> $FILE
		echo "execute pathogen#infect()" >> $FILE

		# Theme Solarized
		echo "Installation du thème Solarized..."
		git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/bundle/vim-colors-solarized
		sed -i 's/\"set background=dark/set background=dark/g' $FILE
		echo "" >> $FILE
		echo "\" Theme Solarized" >> $FILE
		echo "colorscheme solarized" >> $FILE

		# Activation de la coloration syntaxique
		echo "Personnalisation du vimrc..."
		LINENUMBER=$(grep -n '\"syntax on' $FILE | awk -F':' '{ print $1 }')
		sed -i ''$LINENUMBER',+0 s/^\"//g' $FILE

		# Même emplacement à la réouverture du fichier
		LINENUMBER=$(grep -n 'BufReadPost' $FILE | awk -F':' '{ print $1 }')
		LINENUMBER=$((--LINENUMBER))
		sed -i ''$LINENUMBER',+2 s/^\"//g' $FILE

		# Utilisation de la souris
		LINENUMBER=$(grep -n 'set mouse=a' $FILE | awk -F':' '{ print $1 }')
		sed -i ''$LINENUMBER',+0 s/^\"//g' $FILE

		# Ajout des numéros de ligne
		echo "" >> $FILE
		echo "\" Numéros de ligne" >> $FILE
		echo "set nu" >> $FILE
		echo "" >> $FILE

		# Ajout d'une ligne horizontale à l'emplacement du curseur
		echo "\" Ligne horizontale" >> $FILE
		echo "set cursorline" >> $FILE
		echo "highlight CursorLine guibg=#001000" >> $FILE

		read -p "L'installation de Vim s'est bien déroulée."
	fi
}

# Installation du firewall
function firewallInstall {
	# Téléchargement du firewall
	wget https://raw.githubusercontent.com/dwitgsi/LinuxConfig/master/firewall.sh
	# Déplacement et activation du service firewall.sh
	if [ -f firewall.sh ]; then
		chmod u+x firewall.sh
		mv firewall.sh /etc/init.d/
		update-rc.d firewall.sh defaults 20
		systemctl start firewall.service
		echo "L'installation du firewall s'est bien déroulée."
		read -p "Pour modifier les règles, editez le fichier /etc/init.d/firewall.sh"
	else
		read -p "ATTENTION : Le script firewall.sh n'est pas présent."
	fi
}

# Fonction En tete programme
function entete 
{
	getNetworkDatas							# Récupère données réseau
	distrib=$( lsb_release -ds | cut -d" " -f1,3,4 )	# Distribution
	heure=$( date "+%R" )
	ram_tmp=$( free | grep 'Mem' )
	ram_tmp2=$( echo $ram_tmp | cut -d" " -f2 )
	ram=$( echo "scale=2 ; $ram_tmp2/1000000" | bc )
	cpu_tmp=$( sed -n '/model name/p' /proc/cpuinfo | uniq | cut -d":" -f2 )
	cpu=$( echo $cpu_tmp | cut -d" " -f1,2 )
	proc_tmp=$( echo $cpu_tmp | sed "s/$cpu//" | sed "s/CPU//" )
	model_cpu=$( echo $proc_tmp | cut -d"@" -f1 )
	if [[ "$cpu_tmp" = *"ARM"* ]]
	then 
		FcpuTmp=$( cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq )
		Fcpu=$( echo "scale=2 ; $FcpuTmp/1000000" | bc )
	else
		Fcpu=$( echo $proc_tmp | cut -d"@" -f2 )
	fi 
	printf "${blanc}%-15s${neutre}%-18s\n" "LinuxConfig -" "$today $heure" 
	printf "${blanc}%-9s${vertclair}%-21s${blanc}%-8s${vertclair}%-12s${blanc}%-11s${vertclair}%-8s\n" "Machine:" "$HOSTNAME" "User:" "$USER" "RAM:" "$ram""Go"
	printf "${blanc}%-9s${vertclair}%-21s${blanc}%-8s${vertclair}%-12s${blanc}%-10s${vertclair}%-8s\n" "CPU:" "$cpu" "Modele:" "$model_cpu" "Frequence:" "$Fcpu" 
	printf "${blanc}%-9s${vertclair}%-21s${blanc}%-8s${vertclair}%-21s\n" "OS:" "$distrib" "Noyau:" "$noyau" 

	echo -e "${neutre}==============================================================================================="
	while read data_net
	do
		int=$( echo $data_net | cut -d";" -f1 )
		ip=$( echo $data_net | cut -d";" -f2 )
		connect=$( echo $data_net | cut -d";" -f3 )
		addrmac=$( echo $data_net | cut -d";" -f4 )
	printf "${vertclair}%-5s${blanc}%-11s${vertclair}%-9s${blanc}%-6s${vertclair}%-16s${blanc}%-5s${vertclair}%-10s\n" "$int" "Interface:" "$connect" "Ipv4:" "$ip" "MAC:" "$addrmac"
	done < /opt/linuxconfig/netDatabank
	echo -e "${neutre}==============================================================================================="
}

#######################
# Programme principal
#######################

checkPackages "lsb-release bc"	# Vérifie présence des paquets nécessaires

while true
do
	clear
	entete 	# fonction entete
	nmanager=$( dpkg -l | grep '^i' | grep 'network-manager' )
	printf "${blanc}%-4s%-27s%-10s%-8s${blanc}%-2s${neutre}%-15s\n" "No" "Role" "" "" "|" "Description"
	writeLinerInterface "1" "Etat des services" "" "" "Visualisation de l'état des services"
	writeLinerInterface "2" "Post-Installation" "" "" "Configuration de base de la machine"
	writeLinerInterface "5" "Parametres Generaux" "" "" "Gestion des users, disques, MAJ, etc."
	writeLinerInterface "R" "Redémarrer la machine"
	writeLinerInterface "E" "Eteindre la machine"
	writeLinerInterface "Q" "Quitter"
	echo -e "${neutre}==============================================================================================="
	read -p "Votre choix : " choix

	case $choix in

		1 )		# Etat des services
			shift
			clear
			getStates	# Récupère état des roles
			entete
			nmanager=$( dpkg -l | grep '^i' | grep 'network-manager' )
			printf "%s\n" "-------------ETAT DES SERVICES :-------------"
			printf "${blanc}%-4s%-19s%-10s%-8s${blanc}%-2s${cyanclair}%-1s${neutre}%-15s\n" "No" "Role" "Install" "Statut"
			writeLinerInterface "1" "Serveur DNS" "$dnsserver" "$sdns"
			writeLinerInterface "2" "Serveur DHCP" "$dhcpserver" "$sdhcp"
			writeLinerInterface "3" "Serveur SAMBA" "$sambaserver" "$ssamba"
			writeLinerInterface "4" "Serveur NFS" "$nfsserver" "$snfs"
			writeLinerInterface "5" "Serveur SSH" "$sshserver" "$sssh"
			writeLinerInterface "6" "Serveur FTP" "$ftpserver" "$sftp"
			writeLinerInterface "7" "Serveur NTP" "$ntpserver" "$sntp"
			writeLinerInterface "8" "Serveur WEB" "$webserver" "$sweb"
			writeLinerInterface "9" "Serveur Impression" "$cupsserver" "$scups"
			writeLinerInterface "10" "Serveur RADIUS" "$radiusserver" "$sradius"
			writeLinerInterface "11" "Load-balancer" "$haproxyserver" "$shaproxy"
			writeLinerInterface "12" "Mirroir paquets" "$mirroirserver" "$smirroir"
			writeLinerInterface "13" "Routeur" "$role_routeur"
			echo -e "${neutre}==============================================================================================="
			read -p "Appuyez sur entrée pour revenir au menu principal..."
		;;

		2 )		# Menu Post-Installation
			shift
			while [[ true ]]; do
				clear
				entete
				echo -e "---------Paramétrage Post-Installation de la machine---------"
				echo
				writeLinerInterface "0" "Menu principal"
				writeLinerInterface "1" "Installation des paquets principaux" "" "" "cron-apt, fail2ban, logwatch, postfix"
				writeLinerInterface "2" "Instalaltion de Oh-My-Zsh"
				writeLinerInterface "3" "Installation de Vim"
				writeLinerInterface "4" "Installation du firewall"
				writeLinerInterface "5" "Configuration de SSH"
				echo -e "${neutre}==============================================================================================="
				read -p "Votre choix : " choix_PI

				case $choix_PI in

					0 )
						shift
						break
					;;

					1 )
						shift
						checkPackages "cron-apt fail2ban logwatch"
						# Installation de postfix pour permettre l'envoi de mail (sans checkPackages pour avoir l'écran de configuration)
						apt-get install -y postfix
						echo
						echo -n "--------------------------------------------"
						echo -n "Adresse mail pour les rapports de securite: "
						read MAIL
						cronaptConfig #Configuration de l'installation auto des MAJ de sécu
						fail2banConfigBase # Conf sécu SSH et envoi de mail
						logwatchConfig # Envoi de mail quotidiennemment
						read -p "L'installation des principaux paquets s'est bien déroulée."
					;;

					2 )		# Installation de Oh-My-Zsh
						shift
						if [ -d "$ZSH" ]; then
						    printf "${YELLOW}You already have Oh My Zsh installed.${NORMAL}\n"
						    printf "You'll need to remove $ZSH if you want to re-install.\n"
						    read -p "Appuyez sur entrée pour continuer..."
						else
							checkPackages "curl zsh git powerline"
							# Installation de Oh-My-Zsh
							sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
							zshConfig
						fi
					;;

					3 )
						shift
						if [ -f /usr/bin/vim ]; then
							read -p "Vim est déjà installé."
						else
							checkPackages "vim"
							vimConfig
						fi
					;;

					4)
						shift
						if [ -f /etc/init.d/firewall.sh ]; then
							read -p "Le firewall est déjà installé."
						else
							firewallInstall
						fi
					;;

					5)
						shift
						while [[ true ]]; do
							clear
							entete
							echo -e "---------Configuration de SSH---------"
							echo
							writeLinerInterface "0" "Menu précédent"
							writeLinerInterface "1" "Ne pas autoriser la connexion à root"
							writeLinerInterface "2" "Choisir le port"
							echo -e "${neutre}==============================================================================================="
							read -p "Votre choix : " choix_SSH

							case $choix_SSH in
								0 )
									shift
									break
								;;
								1)
									shift
									sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
									service ssh restart
									read -p "OK"
								;;
								2)
									shift
									read -p "Quel est le port à utiliser pour SSH ? : " sshPort

									# Modification de la conf SSH
									sshPortOld=$(grep 'Port [0-9]*' /etc/ssh/sshd_config | cut -c 6-)
									sed -i 's/Port '$sshPortOld'/Port '$sshPort'/g' /etc/ssh/sshd_config

									# Ajout du port dans le firewall
									if [ -f /etc/init.d/firewall.sh ]; then
										lineSSHFirewall=$(grep -n '^TCP_SERVICES=' /etc/init.d/firewall.sh | awk -F':' '{ print $1 }')
										sed -i $lineSSHFirewall' s/'$sshPortOld'/'$sshPort'/' /etc/init.d/firewall.sh
										sed -i 's/SSH_PORT="'$sshPortOld'"/SSH_PORT="'$sshPort'"/' /etc/init.d/firewall.sh
										systemctl daemon-reload
										systemctl restart firewall.service
									fi

									service ssh restart
									read -p "OK"
								;;
							esac
						done
					;;

				esac
			done
		;;

		"R" )		# Redémarrer machine
			shift
			reboot
		;;

		"E" )		# Eteindre machine
			shift
			shutdown -h now
		;;

		"Q" )
			shift
			exit 0
		;;
	esac
done
# Fin du programme