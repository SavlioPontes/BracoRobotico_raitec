import processing.serial.*; // Bibliotecas de comunicacao Serial

Serial portaSerial;
boolean serialConectada = false;
String portaNome = "COM4"; // Altere para a porta correta da ESP32 (ex: COM3)

// Comprimento dos elos
float L1 = 115.0; // Elo 1: S2 - S3
float L2 = 100.0; // Elo 2: S3 - S4
float L3 = 85.0;  // Elo 3: S4 - S5

// Posição inicial de cada servo
float servo0 = 90, servo1 = 90, servo2 = 90, servo3 = 90, servo4 = 90, servo5 = 18;

// Camera inicial da visualização
float camRotX = -0.2;// Start x
float camRotY = 1.5;// Start y
float camZoom = -50.0;
float camX = 0.0; // Deslocamento horizontal da câmera
float camY = 0.0; // Deslocamento vertical da câmera

// Posição das juntas na tela (pixels)
float[] juntaX = new float[4];
float[] juntaY = new float[4];
int juntaAtual = -1;

// Controle de teclas pressionadas
boolean tEsquerda = false;
boolean tDireita = false;

// Logo do RAITec
PImage iconeLogo;

void setup() {
  size(1100, 750, P3D);
  smooth(8);

  iconeLogo = loadImage("raitec_logo.png");

  // Lista as portas seriais disponíveis
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
  translate((width * 0.5) + camX, (height * 0.7) + camY, camZoom);
  rotateX(camRotX);
  rotateY(camRotY);

  lights();
  directionalLight(255, 255, 255, 1, 1, -1);
  ambientLight(100, 100, 110);
  drawFloor();
  drawArm();
  popMatrix();

  // INTERFACE (HUD)
  camera();
  noLights();
  desenharHUD();
}

// Renderização do corpo

void drawArm() {
  stroke(30);

  // Base fixa
  fill(21, 30, 89);
  box(100, 15, 100);

  // Base Servo 1
  criarPonto(0);
  rotateY(-radians(servo0));
  fill(20, 50, 50);
  translate(0, -15, 0);
  box(30, 20, 30); // Caixa S1

  //Servo 2
  translate(0, -10, 0);
  criarPonto(1); // Articulacao do S2
  rotateZ(radians(servo1));
  fill(220, 220, 225);
  translate(0, -L1/2, 0);
  box(22, L1, 22); // Primeiro elo: L1

  //Servo 3
  translate(0, -L1/2, 0);
  criarPonto(2); // Articulacao do S3
  rotateZ(-radians(servo2));
  fill(0, 150, 215);
  translate(0, -L2/2, 0);
  box(18, L2, 18); // Segundo elo: L2

  //Servo 4
  translate(0, -L2/2, 0);
  criarPonto(3); // Articulacao do S4
  rotateZ(-radians(servo3));
  fill(65, 70, 80);
  translate(0, -L3/2, 0);
  box(14, L3, 14); // Terceiro elo: L3

  //Servo 5
  rotateY(radians(servo4 - 90));

  //Servo 6
  float abert = map(servo5, 10, 75, 4, 25);
  fill(200);

  // Garra esquerda
  pushMatrix();
  translate(-abert, -L3/2, 0);
  box(4, 25, 8);
  popMatrix();

  // Garra direita
  pushMatrix();
  translate(abert, -L3/2, 0);
  box(4, 25, 8);
  popMatrix();
}


// Salva a posição 2D do ponto e desenha a esfera
void criarPonto(int id) {
  juntaX[id] = screenX(0, 0, 0);
  juntaY[id] = screenY(0, 0, 0);

  pushMatrix();
  noStroke();
  if (juntaAtual == id) {
    fill(255, 50, 50); // Vermelho (Selecionado)
    sphere(14);
  } else {
    fill(255, 200, 0); // Amarelo (Disponível)
    sphere(10);
  }
  popMatrix();
}

void drawFloor() {
  stroke(40, 45, 55);
  strokeWeight(1);
  for (int i = -300; i <= 300; i += 30) {
    line(i, 0, -300, i, 0, 300);
    line(-300, 0, i, 300, 0, i);
  }
}

//--------------------
// Eventos do Mouse
//--------------------

void mousePressed() {
  // Botão fechar garra 
  if (mouseX >= 20 && mouseX <= 145 && mouseY >= 390 && mouseY <= 425) {
    servo5 -= 20;
    servo5 = constrain(servo5, 10, 75);
    sendToEsp();
    return;
  }

  // Botão abrir garra 
  if (mouseX >= 155 && mouseX <= 280 && mouseY >= 390 && mouseY <= 425) {
    servo5 += 20;
    servo5 = constrain(servo5, 10, 75);
    sendToEsp();
    return;
  }

  // Sliders laterais
  if (mouseX >= 20 && mouseX <= 280) {
    if (mouseY >= 210 && mouseY <= 230) {
      juntaAtual = 0;
      atualizarSliderPorMouse(0, 0, 180);
    } else if (mouseY >= 250 && mouseY <= 270) {
      juntaAtual = 1;
      atualizarSliderPorMouse(1, 10, 175);
    } else if (mouseY >= 290 && mouseY <= 310) {
      juntaAtual = 2;
      atualizarSliderPorMouse(2, 10, 170);
    } else if (mouseY >= 330 && mouseY <= 350) {
      juntaAtual = 3;
      atualizarSliderPorMouse(3, 0, 180);
    } else if (mouseY >= 370 && mouseY <= 390) {
      juntaAtual = 4;
      atualizarSliderPorMouse(4, 0, 180);
    } else {
      juntaAtual = -1;
    }
    return;
  }

  // Aproxima um clique para o modelo 3d
  
  juntaAtual = -1;
  for (int i = 0; i < 4; i++) {
    if (dist(mouseX, mouseY, juntaX[i], juntaY[i]) < 25) {
      juntaAtual = i;
      break;
    }
  }
}

void mouseDragged() {
  // Deslocamento com scroll
  if (mouseButton == CENTER) {
    camX += (mouseX - pmouseX);
    camY += (mouseY - pmouseY);
    return;
  }

  // Lógica Sliders 
  if (mouseX >= 20 && mouseX <= 280 && mouseY >= 200 && mouseY <= 395) {
    if (juntaAtual == 0) atualizarSliderPorMouse(0, 0, 180);
    else if (juntaAtual == 1) atualizarSliderPorMouse(1, 10, 175);
    else if (juntaAtual == 2) atualizarSliderPorMouse(2, 10, 170);
    else if (juntaAtual == 3) atualizarSliderPorMouse(3, 0, 180);
    else if (juntaAtual == 4) atualizarSliderPorMouse(4, 0, 180);
    sendToEsp();
    return;
  }

  // Controle de juntas
  if (juntaAtual != -1 && juntaAtual < 4) {
    float difX = (mouseX - pmouseX) * 0.8;
    float difY = (mouseY - pmouseY) * 0.8;

    if (juntaAtual == 0) servo0 += difX;
    else if (juntaAtual == 1) servo1 -= difY;
    else if (juntaAtual == 2) servo2 += difY;
    else if (juntaAtual == 3) servo3 -= difY;

    servo0 = constrain(servo0, 0, 180);
    servo1 = constrain(servo1, 10, 175);
    servo2 = constrain(servo2, 10, 170);
    servo3 = constrain(servo3, 0, 180);

    sendToEsp();
  } else if (keyPressed && keyCode == SHIFT) {
    camRotY += (mouseX - pmouseX) * 0.01;
    camRotX += (mouseY - pmouseY) * 0.01;
  }
}

void mouseReleased() {
  juntaAtual = -1; // Solta a articulação
}

// Função de zoom com scroll
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  camZoom -= e * 15;
  camZoom = constrain(camZoom, -600, 300);
}

// Lógica de arraste do Slider
void atualizarSliderPorMouse(int servoID, float minVal, float maxVal) {
  float val = map(mouseX, 20, 280, minVal, maxVal);
  val = constrain(val, minVal, maxVal);
  if (servoID == 0) servo0 = val;
  else if (servoID == 1) servo1 = val;
  else if (servoID == 2) servo2 = val;
  else if (servoID == 3) servo3 = val;
  else if (servoID == 4) servo4 = val;
}

// Comando das setas
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

  // Desenha os Sliders para cada Servo
  desenharSlider("S1", 215, servo0, 0, 180, juntaAtual == 0);
  desenharSlider("S2", 255, servo1, 10, 175, juntaAtual == 1);
  desenharSlider("S3", 295, servo2, 10, 170, juntaAtual == 2);
  desenharSlider("S4", 335, servo3, 0, 180, juntaAtual == 3);
  desenharSlider("S5", 375, servo4, 0, 180, juntaAtual == 4);

  // Botões Garra S6
  fill(255);
  textSize(12);
  text("S6 (Garra): " + int(servo5) + "°", 20, 405);

  // Botão Fechar 
  fill(50, 60, 75);
  rect(20, 415, 125, 30, 5);
  fill(255);
  textSize(12);
  text("◀ FECHAR (-20°)", 28, 435);

  // Botão Abrir 
  fill(50, 60, 75);
  rect(155, 415, 125, 30, 5);
  fill(255);
  text("ABRIR (+20°) ▶", 163, 435);


  if (iconeLogo != null) {
    image(iconeLogo, 15, 600, 250, 250); // (imagem, x, y, largura, altura)
  }
}

void desenharSlider(String nome, float yPos, float valor, float minV, float maxV, boolean selecionado) {
  fill(selecionado ? color(50, 255, 50) : 255);
  text(nome + ": " + int(valor) + "°", 20, yPos - 5);

  // Fundo da barra do slider
  fill(40, 45, 55);
  noStroke();
  rect(20, yPos, 260, 10, 5);

  // Preenchimento proporcional do slider
  float larguraPreenchimento = map(valor, minV, maxV, 0, 260);
  fill(selecionado ? color(50, 255, 50) : color(240, 180, 40));
  rect(20, yPos, larguraPreenchimento, 10, 5);
}

void sendToEsp() {
  if (serialConectada) {
    String pacote = "<" + int(servo0) + "," + int(servo1) + "," + int(servo2) + "," + int(servo3) + "," + int(servo4) + "," + int(servo5) + ">\n";
    portaSerial.write(pacote);
  }
}
