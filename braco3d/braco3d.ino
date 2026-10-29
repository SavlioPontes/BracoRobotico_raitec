
#include <ESP32Servo.h>

Servo servo[6];

const int pinos[6] = {15, 2, 21, 33, 22, 32}; // Servos: 1, 2, 3, 4, 5, Garra

// Valida o formato básico do pacote: <...>
bool validarSTR(String msg) {
  return msg.length() >= 3 &&
         msg[0] == '<' &&
         msg[msg.length() - 1] == '>';
}

// Valida os limites de movimento de cada servo
int validarMov(int i, int angulo) {
  switch (i) {
    case 0: // S1
      if (angulo < 0 || angulo > 180) return -1;
      break;

    case 1: // S2
      if (angulo < 20 || angulo > 120) return -1;
      break;

    case 2: // S3
      if (angulo < 30 || angulo > 150) return -1;
      break;

    case 3: // S4
      if (angulo < 0 || angulo > 180) return -1;
      break;

    case 4: // S5
      if (angulo < 40 || angulo > 140) return -1;
      break;
  
    case 5: // S6
      if (angulo < 0 || angulo > 90) return -1;
      break;

    default:
      return -1;
  }

  return angulo;
}

// Separa e valida os seis ângulos recebidos
bool descompactar(String msg, int mov[]) {
  if (!validarSTR(msg)) {
    return false;
  }

  // Remove os caracteres < e >
  msg = msg.substring(1, msg.length() - 1);

  for (int i = 0; i < 6; i++) {
    int fim;

    if (i < 5) {
      fim = msg.indexOf(',');

      if (fim == -1) {
        return false;
      }
    } else {
      fim = msg.length();

      // Impede campos extras após o sexto ângulo
      if (msg.indexOf(',') != -1) {
        return false;
      }
    }

    String valor = msg.substring(0, fim);

    if (valor.length() == 0) {
      return false;
    }

    // Aceita somente números inteiros não negativos
    for (int j = 0; j < valor.length(); j++) {
      if (!isDigit(valor[j])) {
        return false;
      }
    }

    int angulo = valor.toInt();

    mov[i] = validarMov(i, angulo);

    if (i < 5) {
      msg = msg.substring(fim + 1);
    }
  }

  return true;
}

// Move o servo somente se o ângulo for válido
void movServo(int i, int angulo) {
  if (angulo != -1) {
    servo[i].write(angulo);
  }
}

// Processa um pacote completo
void mover(String msg) {
  int mov[6];

  if (!descompactar(msg, mov)) {
    Serial.println("ERRO: pacote invalido");
    return;
  }

  for (int i = 0; i < 6; i++) {
    if (mov[i] == -1) {
      Serial.print("Servo ");
      Serial.print(i + 1);
      Serial.println(": movimento ignorado");
    } else {
      movServo(i, mov[i]);
    }
  }

  Serial.println("OK: pacote processado");
}

void setup() {
  Serial.begin(115200);

  // Inicializa os seis servos
  for (int i = 0; i < 6; i++) {
    servo[i].setPeriodHertz(50);
    servo[i].attach(pinos[i], 500, 2400);
  }

  // Posições iniciais
  servo[0].write(105);
  servo[1].write(120);
  servo[2].write(70);
  servo[3].write(100);
  servo[4].write(0);
  servo[5].write(0); // REVER A GARRA

  Serial.println("Braco robotico pronto.");
}

void loop() {
  static String msg = "";

  while (Serial.available() > 0) {
    char c = Serial.read();

    // Ignora quebras de linha e espaços fora do pacote
    if (c == '\n' || c == '\r' || c == ' ') {
      continue;
    }

    // O caractere < inicia um novo pacote
    if (c == '<') {
      msg = "<";
    }
    else if (msg.length() > 0) {
      msg += c;

      // O caractere > encerra o pacote
      if (c == '>') {
        Serial.print("Recebido: [");
        Serial.print(msg);
        Serial.println("]");

        mover(msg);

        msg = "";
      }
    }
  }
}
