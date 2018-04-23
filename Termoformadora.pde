#include <Timer.h>
#include <LiquidCrystal.h>

#define PRES true
#define NOPRES false
#define FLANCO true
#define NOFLANCO false

//Estados
#define MONITORST 0
#define MENUST    1
#define SELMATST 2
#define TIEMPOST 3
#define MANUALST 4
#define INSERTST  5
#define SELGROSST 6
#define INSERTST 7

//Plasticos
#define PET 0
#define ABS 1
#define PVC 2
#define ACRILICO 3
#define POLIETILENO 4
#define TOTPLASTICOS 5

#define NINGUNO 10

//Grosores
#define g1mm 0
#define g2mm 1
#define g3mm 2
#define g4mm 3
#define g5mm 4
#define TOTGROSORES 5

#define TEMPREADY 100
#define MINTEMP 0
#define STEP (MAXTEMP-MINTEMP)/1023
#define mVtoC 10 //Como si el sensor entregara 10mV por grado centigrado

//Puertos
#define buzzerPin 13
#define botonPin 6
#define botonPinStart botonPin
#define analogPin 0
#define botArribaEst boton[0]
#define botArribaFl botonFlanco[0]
#define botAbajoEst boton[1]
#define botAbajoFl botonFlanco[1]
#define botIzqEst boton[2]
#define botIzqFl botonFlanco[2]
#define botDerEst boton[3]
#define botDerFl botonFlanco[3]

#define ARRIBA 0
#define ABAJO 1
#define IZQ 2
#define DER 3

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
Timer t, Toggler;

//Caracteres especiales
byte FlechaArriba[8] ={
  B00100,
  B01110,
  B10101,
  B00100,
  B00100,
  B00100,
  B00100,
  B00100,
};
byte FlechaAbajo[8] ={
  B00100,
  B00100,
  B00100,
  B00100,
  B00100,
  B10101,
  B01110,
  B00100,
};
byte FlechaDerecha[8] ={
  B00000,
  B00000,
  B00100,
  B00010,
  B11111,
  B00010,
  B00100,
  B00000,
};

byte FlechaIzquierda[8] ={
  B00000,
  B00000,
  B00100,
  B01000,
  B11111,
  B01000,
  B00100,
  B00000,
};

//Variables Globales
long segundos = 0, minutos = 0, horas = 0;
long TiemposEspera[TOTPLASTICOS][TOTGROSORES];
char estado = MONITORST;
char plastico, grosor;
boolean boton[4] = {true, true, true, true};
boolean botonFlanco[4] = {false, false, false, false};

//Flags
boolean flagLCDBusy = false;
boolean SwitchingSt = true; //Avisa a los estados que se acaba de ingresar para que refresquen la pantalla.
boolean RefreshOK = true;
boolean ToggleMessageFlag = false;

void setup()
{
  char i;
  for (i = 0; i < 4; i++)
  {
    pinMode(botonPin + i,INPUT);
    digitalWrite(botonPin + i,HIGH); //Habilito el Resistor de Pull-Up
  }  
  pinMode(buzzerPin,OUTPUT);
  pinMode(analogPin,INPUT);
  analogReference(DEFAULT);
  lcd.begin(16, 2);
  lcd.createChar(0,FlechaArriba);
  lcd.createChar(1,FlechaAbajo);
  lcd.createChar(2,FlechaIzquierda);
  lcd.createChar(3,FlechaDerecha);
  InitTiempos();
  BienvenidaMsj();
  flagLCDBusy = true;
  t.after(3000,ClearLCD);
  t.every(25,Debounce);
  t.every(1000,UpdateClock);
}

void loop()
{
  t.update();
  switch(estado)
  {
    case MONITORST:
      MonitorState();
      break;
    case MENUST:
      MenuState();
      break;
    case SELMATST:
      SeleccionMatState();
      break;
    case TIEMPOST:
     // TiempoState();
      break;
    case MANUALST:
      //ManualState();
      break;
    case SELGROSST:
      SeleccionGrosorState();
      break;
    case INSERTST:
      InsertarState();
      break;
  }
}

void BienvenidaMsj(void)
{
  lcd.setCursor(0,0);
  lcd.print("  electronVolt");
  lcd.setCursor(0,1);
  lcd.print(" Termoformadora");
}


//CONFIGURACION TIEMPOS (en seg) -------------------

void InitTiempos(void)
{
  TiemposEspera[PET][g1mm] = 30;
  TiemposEspera[PET][g2mm] = 60;
  TiemposEspera[PET][g3mm] = 90;
  //TERMINAR
  TiemposEspera[ABS][g1mm] = 40;
  TiemposEspera[ABS][g2mm] = 80;
  //TERMINAR
  TiemposEspera[PVC][g1mm] = 60;
  TiemposEspera[PVC][g2mm] = 120;
  //TERMINAR
  TiemposEspera[ACRILICO][g1mm] = 120;
  TiemposEspera[ACRILICO][g2mm] = 240;
  //TERMINAR
  TiemposEspera[POLIETILENO][g1mm] = 100;
  TiemposEspera[POLIETILENO][g2mm] = 200;
  //TERMINAR
  
}
//MANEJO DE LCD ------------------------------------

void ClearLCD(void) //Esta funcion SIEMPRE libera el LCD! Ojo!
{
  lcd.clear();
  lcd.setCursor(0,0);
  flagLCDBusy = false;
}
void ClearLCDNoClock(void) //Borra el LCD dejando el Reloj, no libera el LCD!
{
  lcd.setCursor(0,0);
  lcd.print("                "); //16 Blancos
  lcd.setCursor(0,1);
  lcd.print("           ");
  lcd.home();
}

//CALLBACKS DE TIMERS --------------------------------------------

void Debounce(void)
{
  static char cont[4] = {0,0,0,0};  
  static boolean EstAnt[4] = {false, false, false, false};
  char i;
  
  for (i = 0; i < 4; i++)
  {
    if ((digitalRead(botonPinStart + i) == HIGH) == EstAnt[i])
    {
      cont[i]++;
      if (cont[i] == 5)
      {
         cont[i] = 0;
         if(boton[i] != EstAnt[i] && EstAnt[i] == 1) //Flanco Descendente
           botonFlanco[i] = FLANCO;
         boton[i] = EstAnt[i];
       
      }
     }else
     {
       EstAnt[i] = (digitalRead(botonPinStart + i) == HIGH);//True si esta presionado
     }
  }
}
  
void UpdateClock(void)
{
  if(segundos < 59)
    segundos++;
  else
  {
    segundos = 0;
    if(minutos < 59) 
      minutos++;
    else
    {
      minutos = 0;
      horas++;
    }
  }
}

void Refresh(void)
{
  RefreshOK = true;
  ToggleMessageFlag = !ToggleMessageFlag;
}

void SelGrosTitle (void)
{
  static char cambiar = 0;
  if (cambiar == 0)
  {
    lcd.setCursor(0,0);
    lcd.print("Seleccione ancho");
    cambiar = 1;
  }else if (cambiar == 1)
  {
    lcd.setCursor(0,0);
    lcd.print("de placa a usar ");
    cambiar = 2;
  }else if (cambiar == 2)
  {
    lcd.setCursor(0,0);
    lcd.print("Volver atras: ");
    lcd.write(byte(0));
    cambiar = 3;
  }else if (cambiar == 3)
  {
    lcd.setCursor(0,0);
    lcd.setCursor(0,0);
    lcd.print("Aceptar: ");
    lcd.write(byte(1));
    lcd.print("      ");
    cambiar = 0;
  }  
}

void SelMatTitle (void)
{
  static char cambiar = 0;
  if (cambiar == 0)
  {
    lcd.setCursor(0,0);
    lcd.print("Seleccione mate- ");
    cambiar = 1;
  }else if (cambiar == 1)
  {
    lcd.setCursor(0,0);
    lcd.print("rial a usar     ");
    cambiar = 2;
  }else if (cambiar == 2)
  {
    lcd.setCursor(0,0);
    lcd.print("Volver atras: ");
    lcd.write(byte(0));
    cambiar = 3;
  }else if (cambiar == 3)
  {
    lcd.setCursor(0,0);
    lcd.setCursor(0,0);
    lcd.print("Aceptar: ");
    lcd.write(byte(1));
    lcd.print("      ");
    cambiar = 0;
  }  
}

//ESTADOS ----------------------------------------------------
void MonitorState(void)
{
  long Valor, TempEnt, TempDec = 0;
  char RefreshID;
  if(SwitchingSt)
  { 
    SwitchingSt = false;
    RefreshID = Toggler.every(2500,Refresh);
  }
  
  Toggler.update();
  
  Valor = (long)analogRead(analogPin);
  TempEnt = Valor * 5 / mVtoC; //cada escalon son 5mV, convertido a grados  
  
  if (TempEnt >= TEMPREADY)
  { 
    estado = MENUST;
    SwitchingSt = true;
    Toggler.stop(RefreshID);
    return; //Borro el refresco de este estado.
  }
  
  //Controlador de Pantalla
  if (ToggleMessageFlag && RefreshOK && !flagLCDBusy)
  {
    RefreshOK = false;
    SwitchingSt = false;
    ClearLCD();
    lcd.print("Calentando...");
    lcd.setCursor(0,1);
    lcd.print("Por favor espere");
  }else if (RefreshOK && !flagLCDBusy)//Al menos tiene que suceder RefreshOK y LCD no ocuapdo
  {
    RefreshOK = false;//Para prevenir actualizaciones constantes (titla la pantalla)
    ClearLCD();
    lcd.print("   Temp.: ");
    lcd.print(TempEnt);
//    if(TempDec)
//    {
//      lcd.print(".");
//      lcd.print(TempDec);
//    }
    lcd.print("C");
  }
  
}

void MenuState()
{
  static char eventID, ProxEstado = 0, ProxMenu;
  if(flagLCDBusy)//Si todavia no se libero el LCD me voy.
    return;
  
  if (SwitchingSt)
  {
    SwitchingSt = false;
    ProxMenu = 0;
    if (plastico != NINGUNO) //Sino, estoy viniendo del menu, no hace falta alarma.
      Toggler.oscillate(buzzerPin,100,HIGH,30);
    eventID = Toggler.every(3000,Refresh);
    ClearLCD();
    lcd.print("Seleccione modo ");
    lcd.setCursor(0,1);
    lcd.write(byte(0));
    lcd.print(":Sel. Material");
  }
  Toggler.update();
  if (RefreshOK && !flagLCDBusy)
  {
    RefreshOK = 0;
    switch(ProxMenu)
    {
      case 0:
        lcd.setCursor(0,1);
        lcd.write(byte(0));//Arriba
        lcd.print(":Sel. Material ");
        ProxMenu++;
        break;
      case 1:
        lcd.setCursor(0,1);
        lcd.write(byte(1));//Abajo
        lcd.print(":Tiempo       ");
        ProxMenu++;
        break;
      case 2:
        lcd.setCursor(0,1);
        lcd.write(byte(2));//Izq
        lcd.print(":Manual       ");
        ProxMenu = 0;
        break;
    }
  }
  
 //Rutina de Polling de Botones
 if (botArribaFl == FLANCO)
 {
    botArribaFl = NOFLANCO;
    ProxEstado = SELMATST;
 }else if (botAbajoFl == FLANCO)
 {
    botAbajoFl = NOFLANCO;
    ProxEstado = TIEMPOST;
 }else if (botIzqFl == FLANCO)
 {
    botIzqFl = NOFLANCO;
    ProxEstado = MANUALST;
 }else
 {
   ProxEstado = 0; //Todavia no!!
   return;
 }
 
 if(ProxEstado != 0)
 {
   estado = ProxEstado;
   SwitchingSt = true;
   Toggler.stop(eventID); //Paro el Toggler
 }
 
  return; 
}

void SeleccionMatState(void)
{ 
  static char eventID[2], MenuPos = 0, MenuPosAnt = 0;
  char ToDo;
  if (SwitchingSt)
  {
    SwitchingSt = false;
    ClearLCD();
    eventID[0] = Toggler.every(3000,SelMatTitle);
    eventID[1] = Toggler.every(1000,Refresh);
    plastico = PET;
    SelMatTitle();
    lcd.setCursor(0,1);
    lcd.print("PET");
    lcd.setCursor(15,1);
    lcd.write(byte(3));
  }
  Toggler.update();
  
  //Rutina de polling de botones

     if (botArribaFl == FLANCO)
     {
        botArribaFl = NOFLANCO;
        ToDo = ARRIBA;
     }else if (botAbajoFl == FLANCO)
     {
        botAbajoFl = NOFLANCO;
        ToDo = ABAJO;
     }else if (botIzqFl == FLANCO)
     {
        botIzqFl = NOFLANCO;
        ToDo = IZQ;
     }else if (botDerFl == FLANCO)
     {
       botDerFl = NOFLANCO;
       ToDo = DER; 
     }else 
     {
       return; //NADA CAMBIO
     }
     //Si llegamos a este punto es porque se toco un boton y hay que alterar
    switch(ToDo)
   {
      case ARRIBA:
        estado = MENUST;
        plastico = NINGUNO;
        SwitchingSt = 1;
        Toggler.stop(eventID[0]);
        Toggler.stop(eventID[1]);
        return;
        break;
      case ABAJO:
        estado = SELGROSST;
        SwitchingSt = 1;
        Toggler.stop(eventID[0]);
        Toggler.stop(eventID[1]);
        return;
        break;
     case IZQ:
       if (plastico == PET) //No se puede ir a la izq de PET
         break;
       plastico--;
       break;
    case DER:
      if (plastico == POLIETILENO) //No se puede ir a la der de POLIETILENO
        break;
      plastico++;
      break;
   }
  switch(plastico)
  {
     case PET:
       lcd.setCursor(0,1);
       lcd.print("PET          ");
       lcd.setCursor(15,1);
       lcd.write(byte(3)); 
       break;
     case ABS:
       lcd.setCursor(0,1);
       lcd.print("ABS          ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.write(byte(3)); 
       break;
     case PVC:
       lcd.setCursor(0,1);
       lcd.print("PVC          ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.write(byte(3)); 
       break;
     case ACRILICO:
       lcd.setCursor(0,1);
       lcd.print("Acrilico     ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.write(byte(3)); 
       break;
     case POLIETILENO:
       lcd.setCursor(0,1);
       lcd.print("Polietileno  ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.setCursor(15,1);
       lcd.print(" ");
       break;
  }
  
}

void SeleccionGrosorState(void)
{
  static char eventID[2];
  char ToDo;
  if (SwitchingSt)
  {
    SwitchingSt = false;
    ClearLCD();
    eventID[0] = Toggler.every(3000,SelGrosTitle);
    eventID[1] = Toggler.every(1000,Refresh);
    grosor = g1mm;
    SelGrosTitle();
    lcd.setCursor(0,1);
    lcd.print("1mm");
    lcd.setCursor(15,1);
    lcd.write(byte(3));
  }
  Toggler.update();
  
  //Rutina de polling de botones

     if (botArribaFl == FLANCO)
     {
        botArribaFl = NOFLANCO;
        ToDo = ARRIBA;
     }else if (botAbajoFl == FLANCO)
     {
        botAbajoFl = NOFLANCO;
        ToDo = ABAJO;
     }else if (botIzqFl == FLANCO)
     {
        botIzqFl = NOFLANCO;
        ToDo = IZQ;
     }else if (botDerFl == FLANCO)
     {
       botDerFl = NOFLANCO;
       ToDo = DER; 
     }else 
     {
       return; //NADA CAMBIO
     }
     //Si llegamos a este punto es porque se toco un boton y hay que alterar
    switch(ToDo)
   {
      case ARRIBA:
        estado = SELMATST;
        grosor = NINGUNO;
        SwitchingSt = 1;
        Toggler.stop(eventID[0]);
        Toggler.stop(eventID[1]);
        return;
        break;
      case ABAJO:
        estado = INSERTST;
        SwitchingSt = 1;
        Toggler.stop(eventID[0]);
        Toggler.stop(eventID[1]);
        return;
        break;
     case IZQ:
       if (grosor == g1mm) //No se puede ir a la izq de 1mm
         break;
       grosor--;
       break;
    case DER:
      if (grosor == g5mm) //No se puede ir a la der de 5mm
        break;
      grosor++;
      break;
   }
  switch(grosor)
  {
     case g1mm:
       lcd.setCursor(0,1);
       lcd.print("1mm          ");
       lcd.setCursor(15,1);
       lcd.write(byte(3)); 
       break;
     case g2mm:
       lcd.setCursor(0,1);
       lcd.print("2mm          ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.write(byte(3)); 
       break;
     case g3mm:
       lcd.setCursor(0,1);
       lcd.print("3mm          ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.write(byte(3)); 
       break;
     case g4mm:
       lcd.setCursor(0,1);
       lcd.print("4mm          ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.write(byte(3)); 
       break;
     case g5mm:
       lcd.setCursor(0,1);
       lcd.print("5mm          ");
       lcd.setCursor(14,1);
       lcd.write(byte(2));
       lcd.setCursor(15,1);
       lcd.print(" ");
       break;
  }
     
}

void InsertarState(void)
{
  if (SwitchingSt)
  {
      SwitchingSt = false;
      ClearLCD();
      lcd.print("Inserte la placa");
      lcd.setCursor(0,1);
      lcd.print("hasta oir el bip");
  }
}
