import processing.serial.*; // Bibliotecas de comunicação Serial

Serial portaSerial;
boolean serialConectada = false;
String portaNome = ""; // Adicionar sua porta COM da ESP

// Comprimento dos elos
float L1 = 105.0;
float L2 = 90.0;
float L3 = 80.0;

// Posição inicial de cada servo
float servo0 = 105;
float servo1 = 120;  
float servo2 = 70;
float servo3 = 100;
float servo4 = 0;
float servo5 = 0; // rever a GARRA

// Câmera inicial
float camRotX = -0.25;
float camRotY = 0;
float camZoom = -50.0;
float camX = 0.0;
float camY = 0.0;

// Posição das juntas na tela
float[] juntaX = new float[4];
float[] juntaY = new float[4];
int juntaAtual = -1;

// Controle de teclas
boolean tEsquerda = false;
boolean tDireita = false;

// Logo do RAITec
PImage iconeLogo;

void setup() {
  size(1100, 750, P3D);
  smooth(8);

  iconeLogo = loadImage("raitec_logo.png");

  println("Portas seriais disponíveis:");
  printArray(Serial.list());

  try {
    portaSerial = new Serial(this, portaNome, 115200);
    serialConectada = true;
    println("Conectado à ESP32 pela porta " + portaNome);
  }
  catch (Exception e) {
    serialConectada = false;
    println("Erro ao conectar à porta " + portaNome);
    println("Detalhes: " + e.getMessage());
  }
}

void draw() {
  background(22, 25, 30);

  if (tEsquerda) {
    servo4 -= 2;
    servo4 = constrain(servo4, 0, 180);
    sendToEsp();
  }

  if (tDireita) {
    servo4 += 2;
    servo4 = constrain(servo4, 0, 180);
    sendToEsp();
  }

  // CENA 3D
  pushMatrix();
  translate((width * 0.5) + camX,
            (height * 0.7) + camY,
            camZoom);

  rotateX(camRotX);
  rotateY(camRotY);

  lights();
  directionalLight(255, 255, 255, 1, 1, -1);
  ambientLight(100, 100, 110);

  drawFloor();
  drawArm();

  popMatrix();

  // INTERFACE
  camera();
  noLights();
  desenharHUD();
}

// Renderização do braço
void drawArm() {
  stroke(30);

  // Base fixa
  fill(21, 30, 89);
  box(300, 15, 300);

  // S1 - Base
  criarPonto(0);
  rotateY(radians(105 - servo0));

  fill(56, 73, 64); 
  translate(0, -15, 0);
  box(40, 20, 40);

  // S2 - Primeiro elo
  translate(0, -10, 0);
  criarPonto(1);

  rotateZ(radians(servo1 - 90));

  fill(41, 45, 50); 
  translate(0, -L1 / 2, 0);
  box(22, L1, 22);

  // S3 - Segundo elo
  translate(0, -L1 / 2, 0);
  criarPonto(2);

  rotateZ(radians(servo2 - 150));

  fill(69, 75, 82);  
  translate(0, -L2 / 2, 0);
  box(18, L2, 18);

  // S4 - Terceiro elo
  translate(0, -L2 / 2, 0);
  criarPonto(3);

  rotateZ(-radians(servo3));

  fill(41, 45, 50);
  translate(0, -L3 / 2, 0);
  box(14, L3, 14);

  // S5 - Rotação da garra
  rotateY(radians(servo4 - 90));

  // S6 - Abertura da garra
  float abert = map(servo5, 10, 75, 25, 4);

  fill(181, 107, 53);   

  // Garra esquerda
  pushMatrix();
  translate(-abert, -L3 / 2, 0);
  box(4, 25, 8);
  popMatrix();

  // Garra direita
  pushMatrix();
  translate(abert, -L3 / 2, 0);
  box(4, 25, 8);
  popMatrix();
}

// Salva a posição 2D e desenha a junta
void criarPonto(int id) {
  juntaX[id] = screenX(0, 0, 0);
  juntaY[id] = screenY(0, 0, 0);

  pushMatrix();
  noStroke();

  if (juntaAtual == id) {
    fill(255, 50, 50);
    sphere(14);
  } else {
    fill(120, 100, 0);
    sphere(10);
  }

  popMatrix();
}

// Piso
void drawFloor() {
  stroke(40, 45, 55);
  strokeWeight(1);

  for (int i = -300; i <= 300; i += 30) {
    line(i, 0, -300, i, 0, 300);
    line(-300, 0, i, 300, 0, i);
  }
}

// Eventos do mouse
void mousePressed() {
  // Fechar garra
  if (mouseX >= 20 && mouseX <= 145 &&
      mouseY >= 415 && mouseY <= 445) {
    servo5 += 20;
    servo5 = constrain(servo5, 10, 75);
    sendToEsp();
    return;
  }

  // Abrir garra
  if (mouseX >= 155 && mouseX <= 280 &&
      mouseY >= 415 && mouseY <= 445) {
    servo5 -= 20;
    servo5 = constrain(servo5, 10, 75);
    sendToEsp();
    return;
  }

  // Sliders
  if (mouseX >= 20 && mouseX <= 280) {
    if (mouseY >= 210 && mouseY <= 230) {
      juntaAtual = 0;
      atualizarSliderPorMouse(0, 0, 180);
    } else if (mouseY >= 250 && mouseY <= 270) {
      juntaAtual = 1;
      atualizarSliderPorMouse(1, 0, 180);
    } else if (mouseY >= 290 && mouseY <= 310) {
      juntaAtual = 2;
      atualizarSliderPorMouse(2, 60, 180);
    } else if (mouseY >= 330 && mouseY <= 350) {
      juntaAtual = 3;
      atualizarSliderPorMouse(3, 0, 130);
    } else if (mouseY >= 370 && mouseY <= 390) {
      juntaAtual = 4;
      atualizarSliderPorMouse(4, 0, 180);
    } else {
      juntaAtual = -1;
    }

    if (juntaAtual != -1) {
      sendToEsp();
    }
    return;
  }

  // Seleção de juntas no modelo 3D
  juntaAtual = -1;

  for (int i = 0; i < 4; i++) {
    if (dist(mouseX, mouseY, juntaX[i], juntaY[i]) < 25) {
      juntaAtual = i;
      break;
    }
  }
}

void mouseDragged() {
  // Mover câmera com botão central
  if (mouseButton == CENTER) {
    camX += mouseX - pmouseX;
    camY += mouseY - pmouseY;
    return;
  }

  // Arraste dos sliders
  if (mouseX >= 20 && mouseX <= 280 &&
      mouseY >= 200 && mouseY <= 395) {

    if (juntaAtual == 0) {
      atualizarSliderPorMouse(0, 0, 180);
    } else if (juntaAtual == 1) {
      atualizarSliderPorMouse(1, 0, 180);
    } else if (juntaAtual == 2) {
     atualizarSliderPorMouse(2, 60, 180);
    } else if (juntaAtual == 3) {
      atualizarSliderPorMouse(3, 0, 130);
    } else if (juntaAtual == 4) {
      atualizarSliderPorMouse(4, 0, 180);
    }

    sendToEsp();
    return;
  }

  // Controle direto das juntas
  if (juntaAtual != -1 && juntaAtual < 4) {
    float difX = (mouseX - pmouseX) * 0.8;
    float difY = (mouseY - pmouseY) * 0.8;

    if (juntaAtual == 0) {
      servo0 += difX;
    } else if (juntaAtual == 1) {
      servo1 -= difY;
    } else if (juntaAtual == 2) {
      servo2 += difY;
    } else if (juntaAtual == 3) {
      servo3 -= difY;
    }

    servo0 = constrain(servo0, 0, 180);
    servo1 = constrain(servo1, 0, 180);
    servo2 = constrain(servo2, 60, 180);
    servo3 = constrain(servo3, 0, 130);

    sendToEsp();
  } else if (keyPressed && keyCode == SHIFT) {
    camRotY += (mouseX - pmouseX) * 0.005;
    camRotX += (mouseY - pmouseY) * 0.005;
  }
}

void mouseReleased() {
  juntaAtual = -1;
}

// Zoom com scroll
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  camZoom -= e * 15;
  camZoom = constrain(camZoom, -600, 300);
}

// Atualização dos sliders
void atualizarSliderPorMouse(
  int servoID, float minVal, float maxVal
) {
  float val = map(mouseX, 20, 280, minVal, maxVal);
  val = constrain(val, minVal, maxVal);

  if (servoID == 0) servo0 = val;
  else if (servoID == 1) servo1 = val;
  else if (servoID == 2) servo2 = val;
  else if (servoID == 3) servo3 = val;
  else if (servoID == 4) servo4 = val;
}

// Comandos das setas
void keyPressed() {
  if (keyCode == LEFT) tEsquerda = true;
  if (keyCode == RIGHT) tDireita = true;
}

void keyReleased() {
  if (keyCode == LEFT) tEsquerda = false;
  if (keyCode == RIGHT) tDireita = false;
}

// HUD
void desenharHUD() {
  fill(18, 20, 25, 230);
  noStroke();
  rect(0, 0, 300, height);

  fill(255);
  textSize(16);
  text("Braço Robótico", 20, 35);

  textSize(12);
  fill(180, 190, 200);
  text("• Clique/Arraste nas Articulações ou Sliders", 20, 60);
  text("• Setas [ < ] [ > ]: Rotação da Garra", 20, 85);
  text("• Scroll do Mouse: Zoom In / Out", 20, 110);
  text("• Clique Scroll + Arrastar: Move Câmera", 20, 135);
  text("• SHIFT + CLIQUE: Gira Câmera 3D", 20, 160);

  stroke(50);
  line(20, 175, 280, 175);

  fill(240, 180, 40);
  text("Painel de Articulações:", 20, 195);

  desenharSlider("S1", 215, servo0, 0, 180, juntaAtual == 0);
  desenharSlider("S2", 255, servo1, 0, 180, juntaAtual == 1);
  desenharSlider("S3", 295, servo2, 60, 180, juntaAtual == 2);
  desenharSlider("S4", 335, servo3, 0, 130, juntaAtual == 3);
  desenharSlider("S5", 375, servo4, 0, 180, juntaAtual == 4);

  fill(255);
  textSize(12);
  text("S6 (Garra): " + int(servo5) + "°", 20, 405);

  // Botão fechar
  fill(50, 60, 75);
  rect(20, 415, 125, 30, 5);

  fill(255);
  text("◀ FECHAR (+20°)", 28, 435);

  // Botão abrir
  fill(50, 60, 75);
  rect(155, 415, 125, 30, 5);

  fill(255);
  text("ABRIR (-20°) ▶", 163, 435);

  if (iconeLogo != null) {
    image(iconeLogo, 15, 600, 250, 250);
  }
}

// Desenho de cada slider
void desenharSlider(
  String nome,
  float yPos,
  float valor,
  float minV,
  float maxV,
  boolean selecionado
) {
  fill(selecionado ? color(50, 255, 50) : 255);
  text(nome + ": " + int(valor) + "°", 20, yPos - 5);

  // Fundo
  fill(40, 45, 55);
  noStroke();
  rect(20, yPos, 260, 10, 5);

  // Preenchimento proporcional
  float larguraPreenchimento =
    map(valor, minV, maxV, 0, 260);

  fill(
    selecionado
    ? color(50, 255, 50)
    : color(240, 180, 20)
  );

  rect(20, yPos, larguraPreenchimento, 10, 5);
}

// Envio dos ângulos para a ESP32
void sendToEsp() {
  if (serialConectada) {
    String pacote =
      "<" +
      int(servo0) + "," +
      int(servo1) + "," +
      int(servo2) + "," +
      int(servo3) + "," +
      int(servo4) + "," +
      int(servo5) +
      ">\n";

    portaSerial.write(pacote);
  }
}
