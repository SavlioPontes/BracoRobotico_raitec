
#include <ESP32Servo.h>

Servo servo[6];

const int pinos[6] = {13, 12, 14, 27, 26, 25};

// Valida o pacote
bool validarSTR(String msg) {
  return msg.length() >= 3 && msg[0] == '<' && msg[msg.length() - 1] == '>';
}

// Valida os limites de cada servo
int validarMov(int i, int angulo) {
  switch (i) {
    case 0:
      if (angulo < 0 || angulo > 180) return -1;
      break;

    case 1:
      if (angulo < 20 || angulo > 120) return -1;
      break;

    case 2:
      if (angulo < 30 || angulo > 150) return -1;
      break;

    case 3:
      if (angulo < 0 || angulo > 180) return -1;
      break;

    case 4:
      if (angulo < 40 || angulo > 140) return -1;
      break;

    case 5:
      if (angulo < 0 || angulo > 90) return -1;
      break;

    default:
      return -1;
  }

  return angulo;
}

// Separa os ângulos recebidos
bool descompactar(String msg, int mov[]) {
  if (!validarSTR(msg)) return false;

  // Remove < e >
  msg = msg.substring(1, msg.length() - 1);

  for (int i = 0; i < 6; i++) {
    int fim;

    if (i < 5) {
      fim = msg.indexOf(',');
      if (fim == -1) return false;
    } else {
      fim = msg.length();
    }

    String valor = msg.substring(0, fim);

    if (valor.length() == 0) return false;
    
    for (int j = 0; j < valor.length(); j++) {
      if (!isDigit(valor[j])) return false;
    }

    int angulo = valor.toInt();
    // -1 indica queo servo mantem a posição
    mov[i] = validarMov(i, angulo);

    if (i < 5) {
      msg = msg.substring(fim + 1);
    }
  }

  return true;
}

// Move o servo indicado apenas se o ângulo for válido
void movServo(int i, int m) {
  if (m != -1) {
    servo[i].write(m);
  }
}

// Processa o pacote recebido
void mover(String msg) {
  int mov[6];

  if (!descompactar(msg, mov)) {
    Serial.println("ERRO: pacote invalido");
    return;
  }

  for (int i = 0; i < 6; i++) {
    if (mov[i] == -1) {
      Serial.print("Servo ");
      Serial.print(i);
      Serial.println(": movimento ignorado");
    } else {
      movServo(i, mov[i]);
    }
  }

  Serial.println("OK: pacote processado");
}

void setup() {
  Serial.begin(115200);

  for (int i = 0; i < 6; i++) {
    servo[i].setPeriodHertz(50);
    servo[i].attach(pinos[i], 500, 2400);
  }
  //posições iniciais:(sincronizadas com o processing)
  servo[0].write(90);
  servo[1].write(90);
  servo[2].write(90);
  servo[3].write(90);
  servo[4].write(90);
  servo[5].write(90);

}

void loop() {
  if (Serial.available() > 0) {
    String msg = Serial.readStringUntil('>');
    msg += '>';

    mover(msg);
  }
}
