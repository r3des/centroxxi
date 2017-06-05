#!/bin/bash
#===============================================================================
#
#          FILE:  at_gen_sleep.sh
#         USAGE:  Llamado manualmente con start|stop|status o automáticamente desde LightDM
#   DESCRIPTION:  Script que realiza las acciones programadas según tiempo de idle
#        AUTHOR:  rog46w
#       VERSION:  1.0
#       CREATED:  25/05/17 08:00
#===============================================================================

source /usr/avatar/bin/at_var_especificas.sh

if [[ $EUID -ne 0 ]]; then
	echo -e "$prefijo Este script solo puede ser llamado por root."
	exit 0
fi

if ! dpkg -l | grep xprintidle | grep -q ii; then
	echo -e "$prefijo El paquete 'xprintidle' no se encuentra instalado. Lo intentamos instalar."
	apt install -y xprintidle &>/dev/null
	if ! dpkg -l | grep xprintidle | grep -q ii; then
		echo -e "$prefijo El paquete 'xprintidle' sigue sin encontrarse instalado. Saliendo de este script."
		exit 0
	fi
fi

#-------------------------------------------------------------------------------
# Bloque START | STOP | STATUS
#-------------------------------------------------------------------------------
case $1 in
"start")
if ps -ef | grep at_gen_sleep.sh | grep -vEq "grep|start"; then
	sleepid=$(ps -ef | grep at_gen_sleep.sh | grep -vE "start|grep" | awk '{print $2}')
	echo -e "$prefijo El servicio de acciones automáticas ya está funcionando (proceso $sleepid)."
else
	echo -e "$prefijo El servicio de acciones automáticas no está funcionando. Lo iniciamos."
	/bin/bash $0 >/dev/null &
fi

exit 0

;;

"stop")

if ps -ef | grep at_gen_sleep.sh | grep -vEq "grep|stop"; then
        sleepid=$(ps -ef | grep at_gen_sleep.sh | grep -vE "stop|grep" | awk '{print $2}')
        echo -e "$prefijo El servicio de acciones automáticas está funcionando (proceso $sleepid). Lo detenemos."
	kill -9 $sleepid
else
        echo -e "$prefijo El servicio de acciones automáticas no está funcionando."
fi

exit 0

;;
"status")

if ps -ef | grep at_gen_sleep.sh | grep -vEq "grep|status"; then
        sleepid=$(ps -ef | grep at_gen_sleep.sh | grep -vE "status|grep" | awk '{print $2}')
        echo -e "$prefijo El servicio de acciones automáticas está funcionando (proceso $sleepid)."
	exit 0
else
        echo -e "$prefijo El servicio de acciones automáticas no está funcionando."
	exit 1
fi

;;
esac

#-------------------------------------------------------------------------------
# Bloque PRINCIPAL: llamada sin parámetro
#-------------------------------------------------------------------------------
echo -e "\n\n$prefijo Iniciando script de acciones automáticas por tiempo de inactividad."

# Fichero acciones: se repite la acción por cada entrada 'acción' del fichero XML
ruta_ficheros_acciones=$RUTA_SUDO/acciones_automaticas

while true; do
	# Regeneramos variables para actualizar timestamp
	source /usr/avatar/bin/at_var_especificas.sh
	# Generamos el idle actual en cada vuelta del bucle permanente
        idle_actual=`xprintidle`
	echo -e "\n$prefijo Realizando comprobación de acciones automáticas."
	idle_minutos=$(echo $idle_actual / 1000 / 60 | bc)
	echo -e "$prefijo El tiempo de inactividad actual es de $idle_minutos minutos."
	for fichero in $ruta_ficheros_acciones/at_acc_*.xml
	do
        	xmllint --noout --dtdvalid $ruta_ficheros_acciones/at_acc_acciones_automaticas.dtd $fichero
	        # El fichero está validado, comprobamos si es necesario realizar la acción
		if [ $? -eq 0 ]; then
        	        # echo -e "$prefijo Validado fichero '$fichero'. Comprobando acción."
	        	nombre="$(xmllint --xpath 'string(//accion/nombre)' $fichero)"
		        idle="$(xmllint --xpath 'string(//accion/idle)' $fichero)"
        		ejecutar="$(xmllint --xpath 'string(//accion/ejecutar)' $fichero)"
			idle_override="$(xmllint --xpath 'string(//accion/idle_override)' $fichero)"
			# Sustituimos el tiempo de inactividad por el configurado por el centro
			if ([ $idle_override -eq $idle_override ] && [ "x$idle_override" != "x" ]); then
				$idle=$idle_override
			fi
			if (( $idle_actual > $idle )); then
        	                echo -e "$prefijo Ejecutando '$nombre', con comando '${ejecutar[$i]}'."
	                        /bin/bash $ejecutar
				if [ $? -eq 0 ]; then
					echo -e "$prefijo El comando se ha ejecutado correctamente."
				else
					echo -e "$prefijo Error al ejecutar el comando para '$nombre'."
				fi
                	fi
		else
			echo -e "$prefijo Error al validar el fichero '$fichero'. Lo ignoramos."
	        fi
	done
	sleep 300
done
