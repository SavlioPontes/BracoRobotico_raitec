import processing.serial.*; // Bibliotecas de comunicação Serial

// =====================================================
//  CONFIGURAÇÕES (mexa aqui)
// =====================================================
String portaNome = "COM15";        // Porta COM da ESP32
boolean SETAS_INVERTIDAS = false;  // true = troca qual seta abre/fecha a garra
float PASSO_TECLA = 2;             // graus por frame ao segurar tecla (setas, W/S, Q/E)
float VELOCIDADE_AUTO = 2.5;       // graus por frame nas posições salvas / sequência
int   PAUSA_SEQUENCIA = 600;       // ms de pausa entre posições na sequência

Serial portaSerial;
boolean serialConectada = false;

// Comprimento dos elos
float L1 = 85.0;
float L2 = 90.0;
float L3 = 80.0;

// =====================================================
//  SERVOS: S1 Base, S2 Ombro, S3 Cotovelo, S4 Punho,
//          S5 Giro da garra, S6 Abertura da garra
// =====================================================
final int N = 6;
String[] nomes = {"S1", "S2", "S3", "S4", "S5", "S6 (Garra)"};

// Limites (iguais aos da ESP32, exceto S3 que fica em 60 por segurança)
float[] minV = {  0,   0,  60,   0,   0, 10};
float[] maxV = {180, 180, 150, 100, 180, 75};

// Posição inicial (a mesma do setup() da ESP32)
float[] HOME = {105, 120, 70, 60, 0, 75};

float[] ang  = HOME.clone();  // ângulo atual (o que aparece e é enviado)
float[] alvo = HOME.clone();  // ângulo desejado (anima até chegar nele)

// =====================================================
//  POSIÇÕES SALVAS (teclas 1 a 9)
//  Estas são só palpites iniciais! Ajuste pelo braço real:
//  mova até a pose desejada, aperte G e depois o número.
// =====================================================
float[][] poses = new float[9][];
String[] posNomes = {
  "Casa", "Empinada (pronta p/ agarrar)", "Esticada à frente",
  "Esquerda", "Direita", "Livre", "Livre", "Livre", "Livre"
};
int poseAtiva = -1;
boolean modoGravar = false;
String arquivoPoses;

// Sequência automática (ESPAÇO)
boolean seqAtivo = false;
int seqIdx = -1;
int seqEspera = 0;

// =====================================================
//  CÂMERA
// =====================================================
float camRotX = -0.25;
float camRotY = 0;
float camZoom = -50.0;
float camX = 0.0;
float camY = 0.0;

// Posição das juntas na tela (para clicar nelas)
float[] juntaX = new float[4];
float[] juntaY = new float[4];

// Junta selecionada (-1 = nenhuma). Agora ela FICA selecionada depois de soltar o mouse.
int juntaAtual = -1;
int arrastando = 0; // 0 = nada, 1 = slider, 2 = junta no 3D

// Teclas seguradas
boolean kEsq, kDir, kCima, kBaixo, kW, kS, kQ, kE;

// Layout do painel
final int SLIDER_Y0 = 250;
final int SLIDER_DY = 36;
final int BTN_Y = 455;
final int PRE_Y = 515;

// Último pacote enviado (para só enviar quando mudar)
int[] ultimoEnviado = {-1, -1, -1, -1, -1, -1};

// Mensagem temporária no painel
String aviso = "";
int avisoAte = 0;

// Logo do RAITec
PImage iconeLogo;

void setup() {
  size(1100, 750, P3D);
  smooth(8);

  iconeLogo = loadImage("raitec_logo.png");

  // Posições padrão
  poses[0] = new float[] {105, 120,  70,  60,   0, 75};
  poses[1] = new float[] {105,  90, 120,  50,  90, 10};
  poses[2] = new float[] {105,  60, 140,  40,  90, 10};
  poses[3] = new float[] {145, 100, 100,  40,  90, 10};
  poses[4] = new float[] { 65, 100, 100,  40,  90, 10};

  arquivoPoses = sketchPath("posicoes.txt");
  carregarPoses();

  println("Portas seriais disponíveis:");
  printArray(Serial.list());

  try {
    portaSerial = new Serial(this, portaNome, 115200);
    serialConectada = true;
    println("Conectado à ESP32 pela porta " + portaNome);
  }
  catch (Exception e) {
    serialConectada = false;
    println("Erro ao conectar à porta " + portaNome + " (rodando só em simulação)");
    println("Detalhes: " + e.getMessage());
  }
}

void draw() {
  background(22, 25, 30);

  processarTeclas();
  atualizarSequencia();
  atualizarMovimento();
  sendToEsp();

  // Descarta as respostas da ESP32 para o buffer não encher
  if (serialConectada) {
    while (portaSerial.available() > 0) portaSerial.read();
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

// =====================================================
//  MOVIMENTO
// =====================================================

// Define um ângulo na hora (controle manual). Cancela animações.
void setAng(int i, float v) {
  ang[i] = constrain(v, minV[i], maxV[i]);
  alvo[i] = ang[i];
  seqAtivo = false;
  poseAtiva = -1;
}

void mover(int i, float delta) {
  if (delta != 0) setAng(i, ang[i] + delta);
}

// Anda suavemente até o alvo; todas as juntas chegam juntas
void atualizarMovimento() {
  float maiorDif = 0;
  for (int i = 0; i < N; i++) {
    maiorDif = max(maiorDif, abs(alvo[i] - ang[i]));
  }
  if (maiorDif < 0.01) return;

  float fator = min(1.0, VELOCIDADE_AUTO / maiorDif);
  for (int i = 0; i < N; i++) {
    ang[i] += (alvo[i] - ang[i]) * fator;
  }
}

boolean chegou() {
  for (int i = 0; i < N; i++) {
    if (abs(alvo[i] - ang[i]) > 0.5) return false;
  }
  return true;
}

// Teclas que ficam sendo seguradas
void processarTeclas() {
  // Garra: um lado fecha (+), o outro abre (-)
  float dirGarra = (kEsq ? 1 : 0) - (kDir ? 1 : 0);
  if (SETAS_INVERTIDAS) dirGarra = -dirGarra;
  mover(5, dirGarra * PASSO_TECLA);

  // Giro da garra (S5)
  mover(4, ((kE ? 1 : 0) - (kQ ? 1 : 0)) * PASSO_TECLA);

  // Junta selecionada: W / cima = +, S / baixo = -
  if (juntaAtual != -1) {
    float dir = ((kW || kCima) ? 1 : 0) - ((kS || kBaixo) ? 1 : 0);
    mover(juntaAtual, dir * PASSO_TECLA);
  }
}

// =====================================================
//  POSIÇÕES E SEQUÊNCIA
// =====================================================
void acionarSlot(int k) {
  if (modoGravar) {
    gravarPose(k);
    return;
  }
  if (poses[k] == null) {
    mostrarAviso("Posição " + (k + 1) + " vazia. Aperte G e depois " + (k + 1) + " para gravar.");
    return;
  }
  seqAtivo = false;
  alvo = poses[k].clone();
  poseAtiva = k;
  mostrarAviso("Posição " + (k + 1) + ": " + posNomes[k]);
}

void irParaCasa() {
  seqAtivo = false;
  alvo = HOME.clone();
  poseAtiva = -1;
  mostrarAviso("Voltando para a posição inicial");
}

void gravarPose(int k) {
  poses[k] = new float[N];
  for (int i = 0; i < N; i++) poses[k][i] = round(ang[i]);
  modoGravar = false;
  salvarPoses();
  mostrarAviso("Pose atual gravada na posição " + (k + 1));
}

void alternarSequencia() {
  if (seqAtivo) {
    seqAtivo = false;
    alvo = ang.clone();
    mostrarAviso("Sequência parada");
  } else {
    seqAtivo = true;
    seqIdx = -1;
    seqEspera = 0;
    mostrarAviso("Sequência automática ligada (ESPAÇO para parar)");
  }
}

void atualizarSequencia() {
  if (!seqAtivo || !chegou()) return;

  if (seqEspera == 0) {
    seqEspera = millis() + PAUSA_SEQUENCIA;
    return;
  }
  if (millis() < seqEspera) return;
  seqEspera = 0;

  for (int t = 0; t < 9; t++) {
    seqIdx = (seqIdx + 1) % 9;
    if (poses[seqIdx] != null) {
      alvo = poses[seqIdx].clone();
      poseAtiva = seqIdx;
      break;
    }
  }
}

void salvarPoses() {
  ArrayList<String> linhas = new ArrayList<String>();
  for (int k = 0; k < 9; k++) {
    if (poses[k] == null) continue;
    String s = str(k);
    for (int i = 0; i < N; i++) s += "," + round(poses[k][i]);
    linhas.add(s);
  }
  saveStrings(arquivoPoses, linhas.toArray(new String[0]));
}

void carregarPoses() {
  if (!new File(arquivoPoses).exists()) return;
  String[] linhas = loadStrings(arquivoPoses);
  if (linhas == null) return;

  for (String linha : linhas) {
    String[] p = split(trim(linha), ',');
    if (p.length != N + 1) continue;
    int k = int(p[0]);
    if (k < 0 || k > 8) continue;
    poses[k] = new float[N];
    for (int i = 0; i < N; i++) {
      poses[k][i] = constrain(float(p[i + 1]), minV[i], maxV[i]);
    }
  }
}

void mostrarAviso(String msg) {
  aviso = msg;
  avisoAte = millis() + 3500;
}

// =====================================================
//  RENDERIZAÇÃO DO BRAÇO
// =====================================================
void drawArm() {
  stroke(30);

  // Base fixa
  fill(21, 30, 89);
  box(300, 15, 300);

  // S1 - Base
  criarPonto(0);
  rotateY(-radians(105 - ang[0]));

  fill(56, 73, 64);
  translate(0, -30, 0);
  box(40, 30, 40);

  // S2 - Primeiro elo
  translate(0, -10, 0);
  criarPonto(1);

  rotateZ(radians(ang[1] - 90));

  fill(41, 45, 50);
  translate(0, -L1 / 2, 0);
  box(22, L1, 22);

  // S3 - Segundo elo
  translate(0, -L1 / 2, 0);
  criarPonto(2);

  rotateZ(radians(ang[2] - 150));

  fill(69, 75, 82);
  translate(0, -L2 / 2, 0);
  box(18, L2, 18);

  // S4 - Terceiro elo
  translate(0, -L2 / 2, 0);
  criarPonto(3);

  rotateZ(-radians(ang[3] + 40));

  fill(41, 45, 50);
  translate(0, -L3 / 2, 0);
  box(14, L3, 14);

  // S5 - Rotação da garra
  rotateY(radians(ang[4] - 90));

  // S6 - Abertura da garra
  float abert = map(ang[5], 10, 75, 25, 4);

  // Os dedos ficam vermelhos quando S5 ou S6 está selecionado
  if (juntaAtual == 4 || juntaAtual == 5) fill(255, 80, 80);
  else fill(181, 107, 53);

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

// =====================================================
//  MOUSE
// =====================================================
int sliderY(int i) {
  return SLIDER_Y0 + i * SLIDER_DY;
}

void mousePressed() {
  arrastando = 0;

  // ---------- Painel lateral ----------
  if (mouseX < 300) {
    // Botão fechar garra
    if (mouseX >= 20 && mouseX <= 145 && mouseY >= BTN_Y && mouseY <= BTN_Y + 30) {
      seqAtivo = false;
      alvo[5] = constrain(ang[5] + 20, minV[5], maxV[5]);
      poseAtiva = -1;
      return;
    }

    // Botão abrir garra
    if (mouseX >= 155 && mouseX <= 280 && mouseY >= BTN_Y && mouseY <= BTN_Y + 30) {
      seqAtivo = false;
      alvo[5] = constrain(ang[5] - 20, minV[5], maxV[5]);
      poseAtiva = -1;
      return;
    }

    // Quadradinhos de posições
    for (int k = 0; k < 9; k++) {
      int x = 20 + k * 28;
      if (mouseX >= x && mouseX <= x + 24 && mouseY >= PRE_Y && mouseY <= PRE_Y + 24) {
        acionarSlot(k);
        return;
      }
    }

    // Sliders
    if (mouseX >= 20 && mouseX <= 280) {
      for (int i = 0; i < N; i++) {
        if (mouseY >= sliderY(i) - 8 && mouseY <= sliderY(i) + 16) {
          juntaAtual = i;
          arrastando = 1;
          atualizarSliderPorMouse(i);
          return;
        }
      }
    }
    return;
  }

  // ---------- Cena 3D ----------
  if (mouseButton == CENTER) return; // botão do meio só move a câmera

  for (int i = 0; i < 4; i++) {
    if (dist(mouseX, mouseY, juntaX[i], juntaY[i]) < 25) {
      juntaAtual = i;
      arrastando = 2;
      return;
    }
  }

  // Clicou no vazio: desseleciona (exceto se for SHIFT para girar a câmera)
  if (!(keyPressed && keyCode == SHIFT)) juntaAtual = -1;
}

void mouseDragged() {
  // Mover câmera com botão central
  if (mouseButton == CENTER) {
    camX += mouseX - pmouseX;
    camY += mouseY - pmouseY;
    return;
  }

  // Girar câmera
  if (keyPressed && keyCode == SHIFT) {
    camRotY += (mouseX - pmouseX) * 0.005;
    camRotX += (mouseY - pmouseY) * 0.005;
    return;
  }

  // Arraste dos sliders
  if (arrastando == 1 && juntaAtual != -1) {
    atualizarSliderPorMouse(juntaAtual);
    return;
  }

  // Controle direto das juntas no 3D
  if (arrastando == 2 && juntaAtual >= 0 && juntaAtual < 4) {
    float difX = (mouseX - pmouseX) * 0.8;
    float difY = (mouseY - pmouseY) * 0.8;

    if (juntaAtual == 0) mover(0, difX);
    else if (juntaAtual == 1) mover(1, -difY);
    else if (juntaAtual == 2) mover(2, difY);
    else if (juntaAtual == 3) mover(3, -difY);
  }
}

void mouseReleased() {
  arrastando = 0; // a junta continua selecionada para usar W / S
}

// Zoom com scroll
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  camZoom -= e * 15;
  camZoom = constrain(camZoom, -600, 300);
}

void atualizarSliderPorMouse(int i) {
  float val = map(mouseX, 20, 280, minV[i], maxV[i]);
  setAng(i, val);
}

// =====================================================
//  TECLADO
// =====================================================
void keyPressed() {
  if (key == CODED) {
    if (keyCode == LEFT)  kEsq = true;
    if (keyCode == RIGHT) kDir = true;
    if (keyCode == UP)    kCima = true;
    if (keyCode == DOWN)  kBaixo = true;
    return;
  }

  char k = Character.toLowerCase(key);

  if (k == 'w') kW = true;
  else if (k == 's') kS = true;
  else if (k == 'q') kQ = true;
  else if (k == 'e') kE = true;
  else if (key == TAB) {
    juntaAtual = (juntaAtual + 1) % N;
  }
  else if (k == 'h') {
    irParaCasa();
  }
  else if (k == 'g') {
    modoGravar = !modoGravar;
  }
  else if (key == ' ') {
    alternarSequencia();
  }
  else if (k >= '1' && k <= '9') {
    acionarSlot(k - '1');
  }
}

void keyReleased() {
  if (key == CODED) {
    if (keyCode == LEFT)  kEsq = false;
    if (keyCode == RIGHT) kDir = false;
    if (keyCode == UP)    kCima = false;
    if (keyCode == DOWN)  kBaixo = false;
    return;
  }

  char k = Character.toLowerCase(key);

  if (k == 'w') kW = false;
  else if (k == 's') kS = false;
  else if (k == 'q') kQ = false;
  else if (k == 'e') kE = false;
}

// =====================================================
//  HUD
// =====================================================
void desenharHUD() {
  fill(18, 20, 25, 230);
  noStroke();
  rect(0, 0, 300, height);

  fill(255);
  textSize(16);
  text("Braço Robótico", 20, 35);

  textSize(11);
  fill(180, 190, 200);
  String[] ajuda = {
    "• Clique numa junta ou slider: seleciona",
    "• W / S (ou Cima / Baixo): move a selecionada",
    "• TAB: seleciona a próxima junta",
    "• Setas [ < ] [ > ]: fecha / abre a garra",
    "• Q / E: gira a garra (S5)",
    "• 1 a 9: vai para a posição   H: posição inicial",
    "• G + número: grava a pose atual naquele slot",
    "• ESPAÇO: liga/desliga sequência automática",
    "• Scroll: zoom   Botão do meio: move câmera",
    "• SHIFT + arrastar: gira câmera 3D"
  };
  for (int i = 0; i < ajuda.length; i++) {
    text(ajuda[i], 20, 58 + i * 15);
  }

  stroke(50);
  line(20, 205, 280, 205);
  noStroke();

  fill(240, 180, 40);
  textSize(12);
  text("Painel de Articulações:", 20, 225);

  for (int i = 0; i < N; i++) {
    desenharSlider(i);
  }

  // Botões da garra
  fill(50, 60, 75);
  rect(20, BTN_Y, 125, 30, 5);
  rect(155, BTN_Y, 125, 30, 5);

  fill(255);
  text("◀ FECHAR (+20°)", 28, BTN_Y + 20);
  text("ABRIR (-20°) ▶", 163, BTN_Y + 20);

  // Posições salvas
  fill(240, 180, 40);
  text("Posições (1-9):", 20, PRE_Y - 8);

  for (int k = 0; k < 9; k++) {
    int x = 20 + k * 28;

    if (modoGravar) fill(170, 50, 50);
    else if (k == poseAtiva) fill(240, 180, 40);
    else if (poses[k] != null) fill(60, 75, 95);
    else fill(35, 38, 45);

    rect(x, PRE_Y, 24, 24, 4);

    fill(k == poseAtiva && !modoGravar ? 0 : 255);
    text(k + 1, x + 8, PRE_Y + 17);
  }

  // Status
  textSize(12);
  if (modoGravar) {
    fill(255, 90, 90);
    text("GRAVAR: aperte 1 a 9 (G cancela)", 20, PRE_Y + 48);
  } else if (millis() < avisoAte) {
    fill(50, 255, 50);
    text(aviso, 20, PRE_Y + 48);
  }

  fill(serialConectada ? color(50, 255, 50) : color(255, 160, 60));
  text(serialConectada ? "Serial: " + portaNome + " conectada"
                       : "Serial: desconectada (só simulação)", 20, PRE_Y + 68);

  if (iconeLogo != null) {
    image(iconeLogo, 15, 600, 250, 250);
  }
}

// Desenho de cada slider
void desenharSlider(int i) {
  float yPos = sliderY(i);
  boolean selecionado = (juntaAtual == i);

  fill(selecionado ? color(50, 255, 50) : color(255));
  text(nomes[i] + ": " + int(ang[i]) + "°", 20, yPos - 5);

  // Fundo
  fill(40, 45, 55);
  noStroke();
  rect(20, yPos, 260, 10, 5);

  // Preenchimento proporcional
  float largura = map(ang[i], minV[i], maxV[i], 0, 260);

  fill(selecionado ? color(50, 255, 50) : color(240, 180, 20));
  rect(20, yPos, largura, 10, 5);
}

// =====================================================
//  SERIAL
// =====================================================
// Envia os ângulos para a ESP32, só quando algo mudou
void sendToEsp() {
  int[] atual = new int[N];
  boolean mudou = false;

  for (int i = 0; i < N; i++) {
    atual[i] = round(ang[i]);
    if (atual[i] != ultimoEnviado[i]) mudou = true;
  }
  if (!mudou) return;

  ultimoEnviado = atual;

  if (serialConectada) {
    String pacote =
      "<" +
      atual[0] + "," +
      atual[1] + "," +
      atual[2] + "," +
      atual[3] + "," +
      atual[4] + "," +
      atual[5] +
      ">\n";

    portaSerial.write(pacote);
  }
}
