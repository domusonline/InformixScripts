#!/bin/sh
# Name: $RCSfile$
# CVS file: $Source$
# CVS id: $Header$
# Revision: $Revision$
# Revised on: $Date$
# Revised by: $Author$
# Support: Fernando Nunes - fernando.nunes@tmn.pt
# Projecto: alarmprogram
# Descricao
#           Funcoes auxiliares para ver se uma data difere mais ou menos que um
#           dado intervalo de outra data
#

#retorna 0 se a diferenca for menor que a dada.
soma()
{
y=`echo $1 | cut -c1-4`
d=`echo $1 | cut -c5-7`
h=`echo $1 | cut -c8-9`
m=`echo $1 | cut -c10-11`
s=`echo $1 | cut -c12-13`
valor=$2
unidade=$3

echo $valor >&2
if [ $unidade = "s" ]
then
   mult=`expr $valor / 60`
   valor=`expr $valor - $mult '*' 60`
   s=`expr $s + $valor`
   valor=$mult
   if [ $s -gt 59 ]
   then
     s=`expr $s - 60`
     valor=`expr $valor + 1`
   fi
   if [ $valor -gt 0 ]
   then
     unidade="m"
   fi
   if [ $s -lt 10 ]
   then
     s="0$s"
   fi
fi

if [ $unidade = "m" ]
then
   mult=`expr $valor / 60`
   valor=`expr $valor - $mult '*' 60`
   m=`expr $m + $valor`
   valor=$mult
   if [ $m -gt 59 ]
   then
     m=`expr $m - 60`
     valor=`expr $valor + 1`
   fi
   if [ $valor -gt 0 ]
   then
     unidade="h"
   fi
   if [ $m -lt 10 ]
   then
     m="0$m"
   fi
fi

if [ $unidade = "h" ]
then
   mult=`expr $valor / 60`
   valor=`expr $valor - $mult '*' 60`
   h=`expr $h + $valor`
   valor=$mult
   if [ $h -gt 23 ]
   then
     h=`expr $h - 24`
     valor=`expr $valor + 1`
   fi
   if [ $valor -gt 0 ]
   then
     unidade="d"
   fi
   if [ $h -lt 10 ]
   then
     h="0$h"
   fi
fi

if [ $unidade = "d" ]
then
   d=`expr $d + $valor`
fi
echo "$y$d$h$m$s"
}

#------------------------------------------
# params:
#         data >    (%Y%j%H%M%S)
#         data <    (%Y%j%H%M%S)
#         intervalo (segundos)
# return:
#         0: d2 + intervalo > d1
#         1: d2 + intervalo <= d1
#------------------------------------------

diff_t1_t2()
{
t1=$1
t2=$2
intervalo=$3

if [ $t1 -lt $t2 ]
then
  return -1
fi

t3=`soma $t2 $intervalo s`

t3_anodia=`echo $t3 | cut -c1-7`
t3_horasegundo=`echo $t3 | cut -c8-13`
t1_anodia=`echo $t1 | cut -c1-7`
t1_horasegundo=`echo $t1 | cut -c8-13`

if [ $t3_anodia -eq $t1_anodia ]
then
	if [ $t3_horasegundo -gt $t1_horasegundo ]
	then
	  return 0
	else
	  return 1
	fi
else
	if [ $t3_anodia -gt $t1_anodia ]
	then
	  return 0
	else
	  return 1
	fi
fi
  
}
