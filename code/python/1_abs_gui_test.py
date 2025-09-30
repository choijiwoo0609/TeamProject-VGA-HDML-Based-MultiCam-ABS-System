# --- merge code
import sys
import cv2
import serial
import time
from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QGridLayout, QFrame, QTextBrowser,
    QVBoxLayout
)
from PyQt5.QtGui import QPixmap, QFont, QImage
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QUrl, QTimer, QPropertyAnimation, QEasingCurve, QPoint
from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent, QMediaPlaylist
from PyQt5.QtMultimediaWidgets import QVideoWidget

# --- 색상 및 설정 ---
OVERLAY_BG_COLOR = '#2E4636'
CHAT_BG_COLOR = '#2E4636'
FONT_COLOR = 'white'
INACTIVE_DOT_COLOR = '#5F6368'
BALL_COLOR = '#8BC34A'
STRIKE_COLOR = '#FBCB0A'
OUT_COLOR = '#D93025'

# --- 전광판 스타일 색상 추가 ---
DIGITAL_GREEN = '#00FF00'  # 밝은 녹색
DIGITAL_YELLOW = '#FFFF00' # 밝은 노란색
DIGITAL_RED = '#FF0000'    # 밝은 빨간색

# ======================
# 비디오 캡처 전용 스레드
# ======================
class VideoThread(QThread):
    frame_signal = pyqtSignal(QImage)
    status_signal = pyqtSignal(str)

    def __init__(self, camera_index=1):
        super().__init__()
        self.camera_index = camera_index
        self.running = True

    def run(self):
        cap = cv2.VideoCapture(self.camera_index, cv2.CAP_DSHOW)
        if not cap.isOpened():
            self.status_signal.emit("카메라 연결 실패")
            return
        self.status_signal.emit("카메라 연결됨")
        while self.running:
            ret, frame = cap.read()
            if ret:
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                h, w, ch = rgb_frame.shape
                bytes_per_line = ch * w
                q_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format_RGB888)
                self.frame_signal.emit(q_image)
        cap.release()

    def stop(self):
        self.running = False
        self.wait()

# ======================
# UART 전용 스레드
# ======================
class UARTThread(QThread):
    data_signal = pyqtSignal(str)
    status_signal = pyqtSignal(str)

    def __init__(self, port='COM13', baudrate=9600):
        super().__init__()
        self.port = port
        self.baudrate = baudrate
        self.running = True
        self.ser = None

    def run(self):
        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=0.1)
            self.status_signal.emit("UART 연결됨")
            while self.running:
                if self.ser.in_waiting:
                    line = self.ser.readline().decode(errors='ignore').strip()
                    if line:
                        self.data_signal.emit(line)
                time.sleep(0.01)
        except Exception as e:
            self.status_signal.emit(f"UART 연결 실패: {e}")
        finally:
            if self.ser and self.ser.is_open:
                self.ser.close()

    def stop(self):
        self.running = False
        self.wait()

# ======================
# 인트로 화면 클래스
# ======================
class IntroScreen(QWidget):
    def __init__(self):
        super().__init__()
        self.music_player = QMediaPlayer()
        self.music_playlist = QMediaPlaylist()
        self.video_player = QMediaPlayer()
        self.video_playlist = QMediaPlaylist()
        self.playlist = QMediaPlaylist()
        self.label = None
        self.blink_timer = None
        self.label_visible = True
        self.initUI()
        self.play_background_music('intro_bgm.mp3')
        self.showFullScreen()

    def initUI(self):
        self.setWindowTitle('인트로 화면')

        # --- 비디오 위젯 ---
        self.video_widget = QVideoWidget(self)
        self.video_widget.setGeometry(self.rect())
        self.video_player.setVideoOutput(self.video_widget)

        # intro.mp4 로드
        intro_video_url = QUrl.fromLocalFile('intro.mp4')
        if intro_video_url.isValid():
            self.video_playlist.addMedia(QMediaContent(intro_video_url))
            self.video_playlist.setPlaybackMode(QMediaPlaylist.CurrentItemOnce)
            self.video_player.setPlaylist(self.video_playlist)
            self.video_player.setVolume(0)
            self.video_player.play()
            self.video_player.mediaStatusChanged.connect(self.handle_video_status)
        else:
            print("오류: 'intro.mp4' 파일을 찾을 수 없거나 유효하지 않습니다.")

        self.label = QLabel(self)
        pixmap = QPixmap("any_key.png")
        self.label.setPixmap(pixmap)
        self.label.setScaledContents(True)
        self.label.setFixedSize(600, 150)
        self.label.setAttribute(Qt.WA_TranslucentBackground)
        self.label.setAlignment(Qt.AlignCenter)

        # 비디오 위에 항상 표시
        self.label.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)

        self.update_label_geometry()

        # 깜빡거림 타이머
        self.blink_timer = QTimer(self)
        self.blink_timer.timeout.connect(self.toggle_label_visibility)

        self.label.hide()
        QTimer.singleShot(3000, self.show_label)  # 3초 후 라벨 보이기 시작

    def toggle_label_visibility(self):
        """라벨을 깜박거리게 제어"""
        if self.label.isVisible():
            self.label.hide()
        else:
            self.label.show()

    def show_label(self):
        if self.label:
            self.label.show()
            # 깜박임 시작
            if self.blink_timer:
                self.blink_timer.start(500)

    def update_label_geometry(self):
        if self.label:
            x = self.width() - 500 - 300
            y = 150
            self.label.setGeometry(x, y, 600, 80)

    def play_background_music(self, music_path):
        url = QUrl.fromLocalFile(music_path)
        if url.isValid():
            self.music_playlist.addMedia(QMediaContent(url))
            self.music_playlist.setPlaybackMode(QMediaPlaylist.Loop)
            self.music_player.setPlaylist(self.music_playlist)
            self.music_player.setVolume(30)
            self.music_player.play()
        else:
            print(f"오류: '{music_path}' 파일을 찾을 수 없거나 유효하지 않습니다.")

    def handle_video_status(self, status):
        if status == QMediaPlayer.EndOfMedia:
            self.video_player.stop()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.close()
        else:
            # 배경음악/비디오 중지
            if self.music_player and self.music_player.state() == QMediaPlayer.PlayingState:
                self.music_player.stop()
            if self.video_player and self.video_player.state() == QMediaPlayer.PlayingState:
                self.video_player.stop()

            # 라벨과 타이머 정리
            if self.blink_timer:
                self.blink_timer.stop()
                self.blink_timer = None
            if self.label:
                self.label.close()
                self.label = None
            
            # 플레이어 선택 화면을 건너뛰고 바로 메인 게임 화면으로 이동
            self.main_gui = BaseballGUI_PyQt()
            self.main_gui.showFullScreen()
            self.close()

    def resizeEvent(self, event):
        self.video_widget.setGeometry(self.rect())
        self.update_label_geometry()

# ======================
# 메인 GUI 클래스
# ======================
class BaseballGUI_PyQt(QWidget):
    def __init__(self):
        super().__init__()
        self.players = {'p1': '플레이어 1', 'p2': '컴퓨터'}        
        self.balls = 0
        self.strikes = 0
        self.outs = 0
        self.video_thread = None
        self.uart_thread = None
        self.chat_window_height = 250
        
        self.effect_label = None
        self.crack_effect_label = None
        self.media_player = QMediaPlayer()        

        # --- 사운드 플레이어 ---
        self.sound_player = QMediaPlayer()
        self.sound_player.mediaStatusChanged.connect(self.handle_sound_finished)

        self.start_bgm_player = QMediaPlayer()
        self.main_bgm_player  = QMediaPlayer()
        self.playlist_main_bgm = QMediaPlaylist()

        self.strike_sound = QUrl.fromLocalFile("sound_strike.wav")
        self.ball_sound   = QUrl.fromLocalFile("sound_ball.wav")
        self.out_sound    = QUrl.fromLocalFile("sound_out.wav")
        self.out_song     = QUrl.fromLocalFile("out_song.mp3")

        self.initUI()
        self.start_threads()
        self.play_start_bgm()
        self.showFullScreen()

    def play_game_bgm(self, music_path='start_bgm.mp3'):
        url = QUrl.fromLocalFile(music_path)
        if url.isValid():
            self.playlist.addMedia(QMediaContent(url))
            self.playlist.setPlaybackMode(QMediaPlaylist.CurrentItemOnce)
            self.media_player.setPlaylist(self.playlist)
            self.media_player.setVolume(50)
            self.media_player.play()
        else:
            print(f"오류: '{music_path}' 파일을 찾을 수 없거나 유효하지 않습니다.")

    def initUI(self):
        self.setWindowTitle('야구 중계 화면 (PyQt5)')
        self.background_label = QLabel(self)
        try:
            pixmap = QPixmap('baseball.jpg')
            self.background_label.setPixmap(pixmap.scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation))
            self.background_label.setGeometry(self.rect())
        except Exception as e:
            self.background_label.setText("'baseball.jpg' 파일을 찾을 수 없습니다.")
            self.background_label.setAlignment(Qt.AlignCenter)
            self.background_label.setGeometry(self.rect())
            print(f"오류: {e}")

        self.video_label = QLabel(self)
        self.video_label.setFixedSize(1333, 1000)
        center_x = (self.width() - self.video_label.width()) // 2
        center_y = (self.height() - self.video_label.height()) // 2
        self.video_label.move(center_x, center_y)

        self.create_chat_window()
        self.create_bso_overlay()
        self.update_bso_display()
        self.add_chat_message(f"플레이어: {self.players['p1']} vs {self.players['p2']}")
        self.add_chat_message("경기 시작!")

    def start_threads(self):
        self.video_thread = VideoThread(camera_index=1)
        self.video_thread.frame_signal.connect(self.update_frame)
        self.video_thread.status_signal.connect(self.handle_status_message)
        self.video_thread.start()

        self.uart_thread = UARTThread(port='COM13', baudrate=9600)
        self.uart_thread.data_signal.connect(self.handle_uart_data)
        self.uart_thread.status_signal.connect(self.handle_status_message)
        self.uart_thread.start()

    def update_frame(self, q_image):
        pixmap = QPixmap.fromImage(q_image)
        self.video_label.setPixmap(pixmap.scaled(
            self.video_label.size(),
            Qt.IgnoreAspectRatio,
            Qt.SmoothTransformation
        ))

    def resizeEvent(self, event):
        if hasattr(self, 'background_label') and self.background_label:
            pixmap = QPixmap('baseball.jpg')
            self.background_label.setPixmap(pixmap.scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation))
            self.background_label.setGeometry(self.rect())

        if hasattr(self, 'video_label') and self.video_label:
            center_x = (self.width() - self.video_label.width()) // 2 + 383
            center_y = (self.height() - self.video_label.height()) // 2 + 60
            self.video_label.move(center_x, center_y)

        if hasattr(self, 'chat_frame') and self.chat_frame:
            x_pos = 20
            y_pos = self.height() - self.chat_frame.height() - 20
            self.chat_frame.move(x_pos, y_pos)

        if hasattr(self, 'overlay_frame') and self.overlay_frame:
            chat_x = self.chat_frame.x()
            chat_y = self.chat_frame.y()
            self.overlay_frame.move(chat_x, chat_y - self.overlay_frame.height() - 10)

    # ======================
    # 채팅창 (디지털 전광판 스타일)
    # ======================
    def create_chat_window(self):
        self.chat_frame = QFrame(self)
        self.chat_frame.setStyleSheet(f"""
            QFrame {{
                background-color: rgba(0, 0, 0, 100);
                border-radius: 8px;
                color: white;
                border: 4px solid white;
            }}
            QTextBrowser {{
                background-color: rgba(0, 0, 0, 100);
                border: none;
                color: white;
            }}
        """)
        layout = QVBoxLayout(self.chat_frame)
        layout.setContentsMargins(15, 10, 15, 10)

        title_font = QFont("휴먼모음T", 30, QFont.Bold)
        text_font = QFont("휴먼모음T", 30)
        
        title_label = QLabel("경기 중계")
        title_label.setFont(title_font)
        title_label.setStyleSheet("color: white;")
        title_label.setAlignment(Qt.AlignCenter)

        self.chat_browser = QTextBrowser()
        self.chat_browser.setFont(text_font)
        self.chat_browser.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)

        layout.addWidget(title_label)
        layout.addWidget(self.chat_browser)

        self.chat_frame.adjustSize()
        self.chat_frame.resize(600, 410)
        x_pos = self.width() - self.chat_frame.width() - 20
        y_pos = self.height() - self.chat_frame.height() - 20
        self.chat_frame.move(x_pos, y_pos)

    def add_chat_message(self, message):
        self.chat_browser.append(f"<span style='color: {DIGITAL_YELLOW};'>{message}</span>")

    # ======================
    # B/S/O 오버레이 (디지털 전광판 스타일)
    # ======================    
    def create_bso_overlay(self):
        self.overlay_frame = QFrame(self)
        self.overlay_frame.setStyleSheet(f"""
            QFrame {{
                background: qradialgradient(cx:0.5, cy:0.5, radius: 0.5, fx:0.5, fy:0.5, stop:0 #1E1E1E, stop:1 #000000);
                background-color: rgba(0, 0, 0, 100);
                border-radius: 8px;
                border: 4px solid white;
            }}
        """)
        layout = QGridLayout(self.overlay_frame)    

        # 채팅창의 높이를 가져와 볼카운트 창의 크기를 결정
        bso_size = self.chat_window_height
        self.overlay_frame.resize(bso_size, bso_size)
        
        # 창 크기에 맞춰 폰트와 점 크기 동적 계산
        bso_font_size = int(bso_size / 4)
        dot_size = int(bso_size / 4)
        
        layout.setContentsMargins(int(bso_size * 0.08), int(bso_size * 0.06), int(bso_size * 0.08), int(bso_size * 0.06))
        layout.setSpacing(int(bso_size * 0.1))

        bso_font = QFont("Consolas", bso_font_size, QFont.Bold)
        b_label = QLabel("B"); b_label.setFont(bso_font); b_label.setStyleSheet(f"color: {DIGITAL_GREEN};")
        s_label = QLabel("S"); s_label.setFont(bso_font); s_label.setStyleSheet(f"color: {DIGITAL_YELLOW};") # S 레이블 색상 변경
        o_label = QLabel("O"); o_label.setFont(bso_font); o_label.setStyleSheet(f"color: {DIGITAL_RED};") # O 레이블 색상 변경

        layout.addWidget(b_label, 0, 0)
        layout.addWidget(s_label, 1, 0)
        layout.addWidget(o_label, 2, 0)

        self.ball_dots = []
        self.strike_dots = []
        self.out_dots = []

        for i in range(3):
            dot = QLabel(); dot.setFixedSize(dot_size, dot_size)
            self.ball_dots.append(dot); layout.addWidget(dot, 0, i+1)

        for i in range(2):
            dot = QLabel(); dot.setFixedSize(dot_size, dot_size)
            self.strike_dots.append(dot); layout.addWidget(dot, 1, i+1)

        for i in range(2):
            dot = QLabel(); dot.setFixedSize(dot_size, dot_size)
            self.out_dots.append(dot); layout.addWidget(dot, 2, i+1)

        self.overlay_frame.adjustSize()
        x_pos = 20
        y_pos = self.height() - self.overlay_frame.height() - 20
        self.overlay_frame.move(x_pos, y_pos)

    def update_bso_display(self):
        dot_radius = self.ball_dots[0].width() // 2
        
        # 볼
        for i, dot_label in enumerate(self.ball_dots):
            if i < self.balls:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: {DIGITAL_GREEN}; border: 1px solid {DIGITAL_GREEN};")
            else:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: transparent; border: 1px solid {DIGITAL_GREEN};")
        
        # 스트라이크
        for i, dot_label in enumerate(self.strike_dots):
            if i < self.strikes:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: {DIGITAL_YELLOW}; border: 1px solid {DIGITAL_YELLOW}; box-shadow: 0 0 5px {DIGITAL_YELLOW};")
            else:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: transparent; border: 1px solid {DIGITAL_YELLOW};")
        
        # 아웃
        for i, dot_label in enumerate(self.out_dots):
            if i < self.outs:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: {DIGITAL_RED}; border: 1px solid {DIGITAL_RED}; box-shadow: 0 0 5px {DIGITAL_RED};")
            else:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: transparent; border: 1px solid {DIGITAL_RED};")

    def handle_uart_data(self, data):
        for char in data.strip().upper():
            if char == "B":
                self.add_ball()
            elif char == "S":
                self.add_strike()

    # ======================
    # 볼 카운트
    # ======================
    def add_ball(self):
        if self.balls < 3:
            self.balls += 1
            self.add_chat_message("볼!")
            self.sound_player.setMedia(QMediaContent(self.ball_sound))
            self.sound_player.setVolume(100)
            self.sound_player.play()
            self.show_ball_effect()
        else:
            self.add_chat_message("볼넷! 주자 진루")
            self.show_ball_effect()
            self.reset_counts()
        self.update_bso_display()

    # ======================
    # 스트라이크 카운트
    # ======================
    def add_strike(self):
        if self.strikes < 2:
            self.strikes += 1
            self.add_chat_message("스트라이크!")
            self.sound_player.setMedia(QMediaContent(self.strike_sound))
            self.sound_player.setVolume(100)
            self.sound_player.play()
            self.show_strike_effect()
        else:
            self.add_chat_message("삼진 아웃!")
            self.add_out()
            self.reset_counts()
        self.update_bso_display()

    # ======================
    # 아웃 카운트
    # ======================
    def add_out(self):
        if self.outs < 2:
            self.outs += 1
            self.add_chat_message("아웃!")
            self.sound_player.setMedia(QMediaContent(self.out_sound))
            self.sound_player.setVolume(60)
            self.sound_player.play()
            self.show_out_effect()
        else:
            self.add_chat_message("이닝 종료! 아웃 카운트 초기화")
            self.outs = 0
            # --- out_song 재생 ---
            self.sound_player.setMedia(QMediaContent(self.out_song))
            self.sound_player.setVolume(100)
            self.sound_player.play()
            # --- main_bgm 잠시 정지 ---
            self.main_bgm_player.pause()
        self.update_bso_display()

    def reset_counts(self):
        self.balls = 0
        self.strikes = 0
        self.update_bso_display()

    def handle_status_message(self, message):
        self.add_chat_message(message)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            if self.video_thread:
                self.video_thread.stop()
            if self.uart_thread:
                self.uart_thread.stop()
            if self.media_player and self.media_player.state() == QMediaPlayer.PlayingState:
                self.media_player.stop()
            self.close()

    # ======================
    # 스트라이크 효과
    # ======================
    def show_strike_effect(self):
        if self.effect_label:
            self.effect_label.deleteLater()
            self.effect_label = None

        self.effect_label = QLabel(self)
        pixmap = QPixmap("font_strike.png")
        self.effect_label.setPixmap(pixmap)
        self.effect_label.setScaledContents(True)
        self.effect_label.setFixedSize(570, 170)

        start_x = -self.effect_label.width()
        start_y = (self.height() - self.effect_label.height()) // 4 - 100
        mid_x = (self.width() - self.effect_label.width()) // 2
        mid_y = start_y
        end_x = self.width()
        end_y = start_y

        self.effect_label.move(start_x, start_y)
        self.effect_label.show()
        self.effect_label.raise_()

        anim = QPropertyAnimation(self.effect_label, b"pos", self)
        anim.setDuration(1000)
        anim.setKeyValueAt(0.0, QPoint(start_x, start_y))
        anim.setKeyValueAt(0.1, QPoint(mid_x, mid_y))
        anim.setKeyValueAt(0.9, QPoint(mid_x, mid_y))
        anim.setKeyValueAt(1.0, QPoint(end_x, end_y))
        anim.setEasingCurve(QEasingCurve.InOutCubic)
        anim.finished.connect(self.hide_effect)
        anim.start(QPropertyAnimation.DeleteWhenStopped)  # 애니메이션 종료 후 자동 삭제

    # ======================
    # 볼 효과
    # ======================
    def show_ball_effect(self):
        if self.effect_label:
            self.effect_label.deleteLater()
            self.effect_label = None

        self.effect_label = QLabel(self)
        pixmap = QPixmap("font_ball.png")
        self.effect_label.setPixmap(pixmap)
        self.effect_label.setScaledContents(True)
        self.effect_label.setFixedSize(470, 200)

        start_x = -self.effect_label.width()
        start_y = (self.height() - self.effect_label.height()) // 4 - 100
        mid_x = (self.width() - self.effect_label.width()) // 2
        mid_y = start_y
        end_x = self.width()
        end_y = start_y

        self.effect_label.move(start_x, start_y)
        self.effect_label.show()
        self.effect_label.raise_()

        anim = QPropertyAnimation(self.effect_label, b"pos", self)
        anim.setDuration(1000)
        anim.setKeyValueAt(0.0, QPoint(start_x, start_y))
        anim.setKeyValueAt(0.1, QPoint(mid_x, mid_y))
        anim.setKeyValueAt(0.9, QPoint(mid_x, mid_y))
        anim.setKeyValueAt(1.0, QPoint(end_x, end_y))
        anim.setEasingCurve(QEasingCurve.InOutCubic)
        anim.finished.connect(self.hide_effect)
        anim.start(QPropertyAnimation.DeleteWhenStopped)

    # ======================
    # 아웃 효과 (크랙 포함)
    # ======================
    def show_out_effect(self):
        if self.effect_label:
            self.effect_label.deleteLater()
            self.effect_label = None
        if self.crack_effect_label:
            self.crack_effect_label.deleteLater()
            self.crack_effect_label = None

        self.effect_label = QLabel(self)
        pixmap = QPixmap("font_out.png")
        self.effect_label.setPixmap(pixmap)
        self.effect_label.setScaledContents(True)
        self.effect_label.setFixedSize(550, 300)

        start_x = -self.effect_label.width()
        start_y = (self.height() - self.effect_label.height()) // 4 - 100
        mid_x = (self.width() - self.effect_label.width()) // 2
        mid_y = start_y
        end_x = self.width()
        end_y = start_y

        self.effect_label.move(start_x, start_y)
        self.effect_label.show()
        self.effect_label.raise_()

        anim = QPropertyAnimation(self.effect_label, b"pos", self)
        anim.setDuration(1000)
        anim.setKeyValueAt(0.0, QPoint(start_x, start_y))
        anim.setKeyValueAt(0.1, QPoint(mid_x, mid_y))
        anim.setKeyValueAt(0.9, QPoint(mid_x, mid_y))
        anim.setKeyValueAt(1.0, QPoint(end_x, end_y))
        anim.setEasingCurve(QEasingCurve.InOutCubic)
        anim.finished.connect(self.hide_effect)
        anim.start(QPropertyAnimation.DeleteWhenStopped)

        # --- 크랙 효과 ---
        self.crack_effect_label = QLabel(self)
        crack_pixmap = QPixmap("crack_effect.png")
        self.crack_effect_label.setPixmap(crack_pixmap)
        self.crack_effect_label.setScaledContents(True)
        self.crack_effect_label.setFixedSize(600, 400)
        self.crack_effect_label.move(mid_x - 50, mid_y - 40)
        self.crack_effect_label.hide()

        QTimer.singleShot(250, self.show_crack_effect)
        QTimer.singleShot(750, self.hide_crack_effect)

    def show_crack_effect(self):
        if self.crack_effect_label:
            self.crack_effect_label.show()
            self.crack_effect_label.raise_()
            self.effect_label.raise_() 

    def hide_crack_effect(self):
        if self.crack_effect_label:
            self.crack_effect_label.hide()

    def hide_effect(self):
        if self.effect_label:
            self.effect_label.hide()
            self.effect_label.deleteLater()
            self.effect_label = None

    # ======================
    # BGM 효과
    # ======================
    def play_start_bgm(self, music_path='start_bgm.mp3'):
        url = QUrl.fromLocalFile(music_path)
        if url.isValid():
            self.start_bgm_player.setMedia(QMediaContent(url))
            self.start_bgm_player.setVolume(50)
            self.start_bgm_player.play()
            self.start_bgm_player.mediaStatusChanged.connect(self.start_bgm_finished)
        else:
            print(f"오류: '{music_path}' 파일을 찾을 수 없습니다.")

    def start_bgm_finished(self, status):
        if status == QMediaPlayer.EndOfMedia:
            self.play_main_bgm()

    def play_main_bgm(self, music_path='main_bgm.mp3'):
        url = QUrl.fromLocalFile(music_path)
        if url.isValid():
            self.playlist_main_bgm.clear()
            self.playlist_main_bgm.addMedia(QMediaContent(url))
            self.playlist_main_bgm.setPlaybackMode(QMediaPlaylist.Loop)
            self.main_bgm_player.setPlaylist(self.playlist_main_bgm)
            self.main_bgm_player.setVolume(20)
            self.main_bgm_player.play()
        else:
            print(f"오류: '{music_path}' 파일을 찾을 수 없습니다.")

    def handle_sound_finished(self, status):
        """out_song 종료 후 main_bgm 재생"""
        if status == QMediaPlayer.EndOfMedia:
            if self.sound_player.media().canonicalUrl() == self.out_song:
                self.main_bgm_player.play()            

# ======================
# 메인 실행
# ======================
if __name__ == '__main__':
    app = QApplication(sys.argv)
    intro = IntroScreen()
    sys.exit(app.exec_())