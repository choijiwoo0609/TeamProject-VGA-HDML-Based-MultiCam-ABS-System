import sys
import cv2
import serial
import time
from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QGridLayout, QFrame, QTextBrowser,
    QVBoxLayout, QHBoxLayout, QPushButton
)
from PyQt5.QtGui import QPixmap, QFont, QImage, QIcon
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QUrl, QTimer, QPropertyAnimation, QEasingCurve, QPoint, QSize
from PyQt5.QtMultimedia import QMediaPlayer, QMediaPlaylist, QMediaContent
from PyQt5.QtMultimediaWidgets import QVideoWidget
import os

# --- 색상 및 설정 ---
OVERLAY_BG_COLOR = '#2E4636'
CHAT_BG_COLOR = '#2E4636'
FONT_COLOR = 'white'
INACTIVE_DOT_COLOR = '#5F6368'
BALL_COLOR = '#8BC34A'
STRIKE_COLOR = '#FBCB0A'
OUT_COLOR = '#D93025'
DIGITAL_GREEN = '#00FF00'
DIGITAL_YELLOW = '#FFFF00'
DIGITAL_RED = '#FF0000'

# ======================
# UART 전용 스레드
# ======================
class UARTThread(QThread):
    data_signal = pyqtSignal(str)
    status_signal = pyqtSignal(str)

    def __init__(self, port='COM10', baudrate=9600):
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
                if self.ser and self.ser.in_waiting:
                    line = self.ser.readline().decode(errors='ignore').strip()
                    if line:
                        self.data_signal.emit(line)
                time.sleep(0.01)
        except Exception as e:
            self.status_signal.emit(f"UART 연결 실패: {e}")
        finally:
            if self.ser and self.ser.is_open:
                try:
                    self.ser.close()
                except:
                    pass

    def stop(self):
        self.running = False
        self.wait()

    def send_data(self, data):
        if self.ser and self.ser.is_open:
            try:
                self.ser.write(data.encode('utf-8'))
                self.status_signal.emit(f"데이터 전송 성공: {data}")
            except Exception as e:
                self.status_signal.emit(f"데이터 전송 실패: {e}")

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
        self.cap = None

    def run(self):
        try:
            self.cap = cv2.VideoCapture(self.camera_index, cv2.CAP_DSHOW)
            if not self.cap.isOpened():
                self.status_signal.emit("카메라 연결 실패")
                self.running = False
                return
            self.status_signal.emit("카메라 연결됨")
            while self.running:
                ret, frame = self.cap.read()
                if ret:
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    h, w, ch = rgb_frame.shape
                    bytes_per_line = ch * w
                    q_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format_RGB888)
                    self.frame_signal.emit(q_image)
                else:
                    time.sleep(0.01)
        except Exception as e:
            self.status_signal.emit(f"VideoThread error: {e}")
        finally:
            if self.cap:
                try:
                    self.cap.release()
                except:
                    pass

    def stop(self):
        self.running = False
        self.wait()

# ======================
# 인트로 화면 클래스 (수정됨)
# ======================
class IntroScreen(QWidget):
    def __init__(self):
        super().__init__()
        # 미디어 플레이어들
        self.music_player = QMediaPlayer()
        self.music_playlist = QMediaPlaylist()
        self.video_player = QMediaPlayer()
        self.video_playlist = QMediaPlaylist()

        # UI 요소
        self.label = None
        self.blink_timer = None
        self.uart_thread = None
        self.mode1_button = None
        self.mode2_button = None
        self.selected_mode = None  # 추가: 현재 선택된 모드 추적

        self.initUI()
        self.start_threads()
        self.play_background_music('intro_bgm.mp3')
        self.showFullScreen()

        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setStyleSheet("background-color: transparent;")

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

    def keep_last_frame(self, status):
        if status == QMediaPlayer.EndOfMedia:
            last_frame_pixmap = QPixmap("intro_last_frame.png")
            self.video_widget.hide()
            self.video_label = QLabel(self)
            self.video_label.setPixmap(last_frame_pixmap.scaled(self.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
            self.video_label.setGeometry(self.rect())
            self.video_label.show()

    def start_threads(self):
        if self.uart_thread and self.uart_thread.isRunning():
            return
        try:
            self.uart_thread = UARTThread(port='COM10', baudrate=9600)
            self.uart_thread.data_signal.connect(self.handle_uart_data_intro)
            self.uart_thread.status_signal.connect(lambda msg: self._debug_msg(f"[Intro UART] {msg}"))
            self.uart_thread.start()
        except Exception as e:
            self._debug_msg(f"UART start error: {e}")
            self.uart_thread = None

    def handle_uart_data_intro(self, data):
        self._debug_msg(f"Intro UART recv: {data}")

    def _debug_msg(self, msg):
        pass

    def play_background_music(self, filename):
        try:
            url = QUrl.fromLocalFile(filename)
            if url.isValid():
                self.music_playlist.clear()
                self.music_playlist.addMedia(QMediaContent(url))
                self.music_playlist.setPlaybackMode(QMediaPlaylist.Loop)
                self.music_player.setPlaylist(self.music_playlist)
                self.music_player.setVolume(30)
                self.music_player.play()
        except Exception as e:
            pass

    def handle_video_status(self, status):
        if status == QMediaPlayer.EndOfMedia:
            self.video_player.stop()

    def keyPressEvent(self, event):
        # Escape 키로 종료
        if event.key() == Qt.Key_Escape:
            if self.uart_thread and self.uart_thread.isRunning():
                try: self.uart_thread.stop()
                except: pass
            self.close()
            return
        
        if self.label.isVisible():
            self.label.hide()
            if self.blink_timer and self.blink_timer.isActive():
                self.blink_timer.stop()
            self.show_mode_buttons()
            return

        if self.mode1_button and self.mode2_button:
            if event.key() == Qt.Key_Up:
                self.selected_mode = "mode1"
                self.update_selection_box()
            elif event.key() == Qt.Key_Down:
                self.selected_mode = "mode2"
                self.update_selection_box()
            elif event.key() == Qt.Key_Return:  # Enter 키
                if self.selected_mode:
                    self.intro_mode_selected(self.selected_mode)

    def show_mode_buttons(self):
        if self.mode1_button or self.mode2_button:
            return

        # 공통 위치 계산
        x = (self.width() - 800)
        y = self.label.y() + self.label.height() + 30

        # --- 모드1 라벨 ---
        self.mode1_button = QLabel(self)
        pixmap1 = QPixmap("label_mode1.png")
        self.mode1_button.setPixmap(pixmap1)
        self.mode1_button.setScaledContents(True)
        self.mode1_button.setFixedSize(600, 100)
        self.mode1_button.move(x, y)
        self.mode1_button.setStyleSheet("background: transparent;")
        self.mode1_button.setAttribute(Qt.WA_TranslucentBackground)
        self.mode1_button.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.mode1_button.show()

        # --- 모드2 라벨 ---
        self.mode2_button = QLabel(self)
        pixmap2 = QPixmap("label_mode2.png")
        self.mode2_button.setPixmap(pixmap2)
        self.mode2_button.setScaledContents(True)
        self.mode2_button.setFixedSize(600, 100)
        self.mode2_button.move(x, y + 120)
        self.mode2_button.setStyleSheet("background: transparent;")
        self.mode2_button.setAttribute(Qt.WA_TranslucentBackground)
        self.mode2_button.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.mode2_button.show()

        # 초기 선택 모드
        self.selected_mode = "mode1"
        self.update_selection_box()


            
    def update_selection_box(self):
        """선택된 모드만 확대, 나머지는 원래 크기"""
        if not (self.mode1_button and self.mode2_button):
            return

        base_width, base_height = 600, 100
        scale_factor = 1.2

        pixmap1 = QPixmap("label_mode1.png")
        pixmap2 = QPixmap("label_mode2.png")

        if self.selected_mode == "mode1":
            # 모드1 확대
            new_w1 = int(base_width * scale_factor)
            new_h1 = int(base_height * scale_factor)
            self.mode1_button.setPixmap(pixmap1.scaled(new_w1, new_h1, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            self.mode1_button.setFixedSize(new_w1, new_h1)

            # 모드2 원래 크기
            self.mode2_button.setPixmap(pixmap2.scaled(base_width, base_height, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            self.mode2_button.setFixedSize(base_width, base_height)
        else:
            # 모드2 확대
            new_w2 = int(base_width * scale_factor)
            new_h2 = int(base_height * scale_factor)
            self.mode2_button.setPixmap(pixmap2.scaled(new_w2, new_h2, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            self.mode2_button.setFixedSize(new_w2, new_h2)

            # 모드1 원래 크기
            self.mode1_button.setPixmap(pixmap1.scaled(base_width, base_height, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            self.mode1_button.setFixedSize(base_width, base_height)

        # 위치 다시 계산 (중앙 정렬, 겹치지 않도록)
        x = (self.width() - 800)
        self.mode1_button.move(x, self.label.y() + self.label.height() - 120)
        x2 = (self.width() - 800)
        self.mode2_button.move(x2, self.label.y() + self.label.height() + 30)

    def intro_mode_selected(self, mode):
        try:
            if self.uart_thread:
                self.uart_thread.send_data("1" if mode == "mode1" else "2")
        except Exception:
            pass
        if self.uart_thread and self.uart_thread.isRunning():
            self.uart_thread.stop()  # 스레드 종료 요청
            self.uart_thread.wait()  # 스레드가 완전히 종료될 때까지 대기
            try: QTimer.singleShot(50, lambda: self.uart_thread.stop())
            except Exception: pass
        
        if self.label:
            self.label.hide()
        if self.blink_timer and self.blink_timer.isActive():
            self.blink_timer.stop()
        
        if self.mode1_button:
            self.mode1_button.hide(); self.mode1_button.deleteLater(); self.mode1_button = None
        if self.mode2_button:
            self.mode2_button.hide(); self.mode2_button.deleteLater(); self.mode2_button = None

        try:
            if self.music_player:
                self.music_player.stop()
        except:
            pass

        self.close()

        try:
            self.main_gui = BaseballGUI_PyQt(mode=mode)
            self.main_gui.showFullScreen()
        except Exception as e:
            print("Main GUI start error:", e)

    def update_label_geometry(self):
        if self.label:
            x = self.width() - 800
            y = 150
            self.label.setGeometry(x, y, self.label.width(), self.label.height())

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.video_widget.setGeometry(self.rect())
        self.update_label_geometry() 

        # 모드 라벨 위치 조정
        if self.mode1_button:
            x = (self.width() - self.mode1_button.width()) // 2
            self.mode1_button.move(x, self.label.y() + self.label.height() + 30)
        if self.mode2_button:
            x = (self.width() - self.mode2_button.width()) // 2
            self.mode2_button.move(x, self.label.y() + self.label.height() + 150)

        def closeEvent(self, event):
            if self.uart_thread and self.uart_thread.isRunning():
                try: self.uart_thread.stop()
                except: pass
            try:
                if self.video_player and self.video_player.state() == QMediaPlayer.PlayingState:
                    self.video_player.stop()
            except:
                pass
            super().closeEvent(event)

# ======================
# 메인 GUI 클래스 (원본 로직 유지, start_threads 호출 위치 고침)
# ======================
class BaseballGUI_PyQt(QWidget):
    def __init__(self, mode=0):
        super().__init__()
        self.players = {'p1': '플레이어 1', 'p2': '컴퓨터'}
        self.balls = 0
        self.strikes = 0
        self.outs = 0
        self.score = 0
        self.video_thread = None
        self.uart_thread = None
        self.chat_window_height = 250
        self.mode = mode

        self.effect_label = None
        self.crack_effect_label = None
        self.sound_player = QMediaPlayer()
        self.sound_player.mediaStatusChanged.connect(self.handle_sound_finished)
        self.start_bgm_player = QMediaPlayer()
        self.main_bgm_player = QMediaPlayer()
        self.playlist_main_bgm = QMediaPlaylist()

        self.strike_sound = QUrl.fromLocalFile("sound_strike.wav")
        self.ball_sound = QUrl.fromLocalFile("sound_ball.wav")
        self.out_sound = QUrl.fromLocalFile("sound_out.wav")
        self.out_song = QUrl.fromLocalFile("out_song.mp3")

        # UI 초기화
        self.initUI()

        # 스레드 및 BGM 시작 (잘못된 self.uart_thread() 호출 대신)
        self.start_threads()
        self.play_start_bgm()

        self.showFullScreen()

    def initUI(self):
        self.setWindowTitle('야구 중계 화면 (PyQt5)')
        self.background_label = QLabel(self)
        try:
            pixmap = QPixmap('baseball.jpg')
            if not pixmap.isNull():
                self.background_label.setPixmap(pixmap.scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation))
            else:
                self.background_label.setText("'baseball.jpg' 파일을 찾을 수 없습니다.")
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
        self.create_scoreboard()
        self.update_bso_display()
        self.update_scoreboard()
        self.add_chat_message(f"플레이어: {self.players['p1']} vs {self.players['p2']}")
        self.add_chat_message("경기 시작!")
        self.add_chat_message(f"현재 모드: {'ABS 시스템' if self.mode == 'mode1' else '표적 맞추기'}")

        # 모드에 따라 표시 전환
        if self.mode == 'mode2':
            if hasattr(self, 'overlay_frame'):
                self.overlay_frame.hide()
            if hasattr(self, 'score_frame'):
                self.score_frame.show()
        else:
            if hasattr(self, 'overlay_frame'):
                self.overlay_frame.show()
            if hasattr(self, 'score_frame'):
                self.score_frame.hide()

    def start_threads(self):
        # 비디오 스레드
        if not self.video_thread or not self.video_thread.isRunning():
            self.video_thread = VideoThread(camera_index=1)
            self.video_thread.frame_signal.connect(self.update_frame)
            self.video_thread.status_signal.connect(self.handle_status_message)
            self.video_thread.start()

        # UART 스레드
        if not self.uart_thread or not self.uart_thread.isRunning():
            self.uart_thread = UARTThread(port='COM10', baudrate=9600)
            self.uart_thread.data_signal.connect(self.handle_uart_data)
            self.uart_thread.status_signal.connect(self.handle_status_message)
            self.uart_thread.start()

    # ... (나머지 메서드는 이전에 제공된 로직을 그대로 사용합니다)
    # 아래에는 핵심적으로 필요한 메서드들(축약하지 않고 포함)만 넣습니다.

    def update_frame(self, q_image):
        try:
            pixmap = QPixmap.fromImage(q_image)
            self.video_label.setPixmap(pixmap.scaled(
                self.video_label.size(),
                Qt.IgnoreAspectRatio,
                Qt.SmoothTransformation
            ))
        except Exception:
            pass

    def resizeEvent(self, event):
        super().resizeEvent(event)
        try:
            pixmap = QPixmap('baseball.jpg')
            if not pixmap.isNull() and hasattr(self, 'background_label'):
                self.background_label.setPixmap(pixmap.scaled(self.size(), Qt.IgnoreAspectRatio, Qt.SmoothTransformation))
                self.background_label.setGeometry(self.rect())
        except Exception:
            pass

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

        if hasattr(self, 'score_frame') and self.score_frame:
            chat_x = self.chat_frame.x()
            chat_y = self.chat_frame.y()
            self.score_frame.move(chat_x, chat_y - self.score_frame.height() - 10)

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
        try:
            self.chat_browser.append(f"<span style='color: {DIGITAL_YELLOW};'>{message}</span>")
        except Exception:
            pass

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

        bso_size = self.chat_window_height
        self.overlay_frame.resize(bso_size, bso_size)

        bso_font_size = int(bso_size / 4)
        dot_size = int(bso_size / 4)

        layout.setContentsMargins(int(bso_size * 0.08), int(bso_size * 0.06), int(bso_size * 0.08), int(bso_size * 0.06))
        layout.setSpacing(int(bso_size * 0.1))

        bso_font = QFont("Consolas", bso_font_size, QFont.Bold)
        b_label = QLabel("B"); b_label.setFont(bso_font); b_label.setStyleSheet(f"color: {DIGITAL_GREEN};")
        s_label = QLabel("S"); s_label.setFont(bso_font); s_label.setStyleSheet(f"color: {DIGITAL_YELLOW};")
        o_label = QLabel("O"); o_label.setFont(bso_font); o_label.setStyleSheet(f"color: {DIGITAL_RED};")

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
        try:
            dot_radius = self.ball_dots[0].width() // 2
        except Exception:
            return

        for i, dot_label in enumerate(self.ball_dots):
            if i < self.balls:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: {DIGITAL_GREEN}; border: 1px solid {DIGITAL_GREEN};")
            else:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: transparent; border: 1px solid {DIGITAL_GREEN};")

        for i, dot_label in enumerate(self.strike_dots):
            if i < self.strikes:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: {DIGITAL_YELLOW}; border: 1px solid {DIGITAL_YELLOW};")
            else:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: transparent; border: 1px solid {DIGITAL_YELLOW};")

        for i, dot_label in enumerate(self.out_dots):
            if i < self.outs:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: {DIGITAL_RED}; border: 1px solid {DIGITAL_RED};")
            else:
                dot_label.setStyleSheet(f"border-radius: {dot_radius}px; background-color: transparent; border: 1px solid {DIGITAL_RED};")

    def create_scoreboard(self):
        self.score_frame = QFrame(self)
        self.score_frame.setStyleSheet(f"""
            QFrame {{
                background-color: rgba(0, 0, 0, 180);
                border-radius: 8px;
                border: 4px solid white;
            }}
            QLabel {{
                color: white;
            }}
        """)
        layout = QVBoxLayout(self.score_frame)
        layout.setContentsMargins(20, 10, 20, 10)
        layout.setAlignment(Qt.AlignCenter)

        title_font = QFont("휴먼모음T", 50, QFont.Bold)
        score_font = QFont("Consolas", 150, QFont.Bold)

        title_label = QLabel("SCORE")
        title_label.setFont(title_font)
        title_label.setAlignment(Qt.AlignCenter)
        title_label.setFixedSize(550, 100)

        self.score_label = QLabel("0")
        self.score_label.setFont(score_font)
        self.score_label.setAlignment(Qt.AlignCenter)
        self.score_label.setStyleSheet(f"color: {DIGITAL_GREEN};")
        self.score_label.setFixedSize(550, 200)

        layout.addWidget(title_label)
        layout.addWidget(self.score_label)

        self.score_frame.adjustSize()
        self.score_frame.resize(600, 360)
        x_pos = 20
        y_pos = self.height() - self.score_frame.height() - 20
        self.score_frame.move(x_pos, y_pos)

        self.score_frame.hide()

    def update_scoreboard(self):
        if hasattr(self, 'score_label'):
            try:
                self.score_label.setText(str(self.score))
            except Exception:
                pass

    def handle_uart_data(self, data):
        for char in data.strip().upper():
            if self.mode == 'mode1' or self.mode == 0:
                if char == "B":
                    self.add_ball()
                elif char == "S":
                    self.add_strike()
            elif self.mode == 'mode2':
                if char == "C":
                    self.score += 100
                    self.add_chat_message(f"표적 적중! +100점 (합계: {self.score})")
                    self.update_scoreboard()

    def apply_selected_mode(self, selected_mode):
        self.mode = selected_mode
        self.show()
        self.start_threads()
        self.add_chat_message(f"모드가 {'ABS 시스템' if self.mode == 'mode1' else '표적 맞추기'}로 변경되었습니다.")
        self.reset_counts()
        self.outs = 0
        if self.mode == 'mode2':
            if hasattr(self, 'overlay_frame'):
                self.overlay_frame.hide()
            if hasattr(self, 'score_frame'):
                self.score_frame.show()
            self.score = 0
            self.update_scoreboard()
        else:
            if hasattr(self, 'overlay_frame'):
                self.overlay_frame.show()
            if hasattr(self, 'score_frame'):
                self.score_frame.hide()

    def add_ball(self):
        if self.balls < 3:
            self.balls += 1
            self.add_chat_message("볼!")
            try:
                self.sound_player.setMedia(QMediaContent(self.ball_sound))
                self.sound_player.setVolume(100)
                self.sound_player.play()
            except:
                pass
            self.show_ball_effect()
        else:
            self.add_chat_message("볼넷! 주자 진루")
            self.show_ball_effect()
            self.reset_counts()
        self.update_bso_display()

    def add_strike(self):
        if self.strikes < 2:
            self.strikes += 1
            self.add_chat_message("스트라이크!")
            try:
                self.sound_player.setMedia(QMediaContent(self.strike_sound))
                self.sound_player.setVolume(100)
                self.sound_player.play()
            except:
                pass
            self.show_strike_effect()
        else:
            self.add_chat_message("삼진 아웃!")
            self.add_out()
            self.reset_counts()
        self.update_bso_display()

    def add_out(self):
        if self.outs < 2:
            self.outs += 1
            self.add_chat_message("아웃!")
            try:
                self.sound_player.setMedia(QMediaContent(self.out_sound))
                self.sound_player.setVolume(60)
                self.sound_player.play()
            except:
                pass
            self.show_out_effect()
        else:
            self.add_chat_message("이닝 종료! 아웃 카운트 초기화")
            self.outs = 0
            try:
                self.sound_player.setMedia(QMediaContent(self.out_song))
                self.sound_player.setVolume(100)
                self.sound_player.play()
            except:
                pass
            try:
                self.main_bgm_player.pause()
            except:
                pass
        self.update_bso_display()

    def reset_counts(self):
        self.balls = 0
        self.strikes = 0
        self.update_bso_display()

    def handle_status_message(self, message):
        self.add_chat_message(message)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.close()

    def closeEvent(self, event):
        self.stop_threads()
        super().closeEvent(event)

    def stop_threads(self):
        try:
            if self.video_thread and self.video_thread.isRunning():
                self.video_thread.stop()
        except:
            pass
        try:
            if self.uart_thread and self.uart_thread.isRunning():
                self.uart_thread.stop()
        except:
            pass
        try:
            if self.main_bgm_player:
                self.main_bgm_player.stop()
        except:
            pass

    # Effects & sound helpers (kept original logic; errors guarded)
    def show_strike_effect(self):
        if self.effect_label: 
            try: self.effect_label.deleteLater()
            except: pass
            self.effect_label = None
        self.effect_label = QLabel(self)
        pixmap = QPixmap("font_strike.png")
        self.effect_label.setPixmap(pixmap)
        self.effect_label.setScaledContents(True)
        self.effect_label.setFixedSize(570, 170)
        start_x = -self.effect_label.width(); start_y = (self.height() - self.effect_label.height()) // 4 - 100
        mid_x = (self.width() - self.effect_label.width()) // 2; mid_y = start_y; end_x = self.width(); end_y = start_y
        self.effect_label.move(start_x, start_y); self.effect_label.show(); self.effect_label.raise_()
        anim = QPropertyAnimation(self.effect_label, b"pos", self); anim.setDuration(1000)
        anim.setKeyValueAt(0.0, QPoint(start_x, start_y)); anim.setKeyValueAt(0.1, QPoint(mid_x, mid_y)); anim.setKeyValueAt(0.9, QPoint(mid_x, mid_y)); anim.setKeyValueAt(1.0, QPoint(end_x, end_y))
        anim.setEasingCurve(QEasingCurve.InOutCubic); anim.finished.connect(self.hide_effect); anim.start(QPropertyAnimation.DeleteWhenStopped)

    def show_ball_effect(self):
        if self.effect_label:
            try: self.effect_label.deleteLater()
            except: pass
            self.effect_label = None
        self.effect_label = QLabel(self)
        pixmap = QPixmap("font_ball.png")
        self.effect_label.setPixmap(pixmap)
        self.effect_label.setScaledContents(True)
        self.effect_label.setFixedSize(470, 200)
        start_x = -self.effect_label.width(); start_y = (self.height() - self.effect_label.height()) // 4 - 100
        mid_x = (self.width() - self.effect_label.width()) // 2; mid_y = start_y; end_x = self.width(); end_y = start_y
        self.effect_label.move(start_x, start_y); self.effect_label.show(); self.effect_label.raise_()
        anim = QPropertyAnimation(self.effect_label, b"pos", self); anim.setDuration(1000)
        anim.setKeyValueAt(0.0, QPoint(start_x, start_y)); anim.setKeyValueAt(0.1, QPoint(mid_x, mid_y)); anim.setKeyValueAt(0.9, QPoint(mid_x, mid_y)); anim.setKeyValueAt(1.0, QPoint(end_x, end_y))
        anim.setEasingCurve(QEasingCurve.InOutCubic); anim.finished.connect(self.hide_effect); anim.start(QPropertyAnimation.DeleteWhenStopped)

    def show_out_effect(self):
        if self.effect_label:
            try: self.effect_label.deleteLater()
            except: pass
            self.effect_label = None
        if self.crack_effect_label:
            try: self.crack_effect_label.deleteLater()
            except: pass
            self.crack_effect_label = None
        self.effect_label = QLabel(self)
        pixmap = QPixmap("font_out.png")
        self.effect_label.setPixmap(pixmap)
        self.effect_label.setScaledContents(True)
        self.effect_label.setFixedSize(550, 300)
        start_x = -self.effect_label.width(); start_y = (self.height() - self.effect_label.height()) // 4 - 100
        mid_x = (self.width() - self.effect_label.width()) // 2; mid_y = start_y; end_x = self.width(); end_y = start_y
        self.effect_label.move(start_x, start_y); self.effect_label.show(); self.effect_label.raise_()
        anim = QPropertyAnimation(self.effect_label, b"pos", self); anim.setDuration(1000)
        anim.setKeyValueAt(0.0, QPoint(start_x, start_y)); anim.setKeyValueAt(0.1, QPoint(mid_x, mid_y)); anim.setKeyValueAt(0.9, QPoint(mid_x, mid_y)); anim.setKeyValueAt(1.0, QPoint(end_x, end_y))
        anim.setEasingCurve(QEasingCurve.InOutCubic); anim.finished.connect(self.hide_effect); anim.start(QPropertyAnimation.DeleteWhenStopped)
        self.crack_effect_label = QLabel(self)
        crack_pixmap = QPixmap("crack_effect.png")
        self.crack_effect_label.setPixmap(crack_pixmap)
        self.crack_effect_label.setScaledContents(True)
        self.crack_effect_label.setFixedSize(600, 400)
        self.crack_effect_label.move(mid_x - 50, mid_y - 40)
        self.crack_effect_label.hide()
        QTimer.singleShot(250, self.show_crack_effect); QTimer.singleShot(750, self.hide_crack_effect)

    def show_crack_effect(self):
        if self.crack_effect_label:
            self.crack_effect_label.show(); self.crack_effect_label.raise_(); self.effect_label.raise_()

    def hide_crack_effect(self):
        if self.crack_effect_label:
            self.crack_effect_label.hide()

    def hide_effect(self):
        if self.effect_label:
            try: self.effect_label.hide(); self.effect_label.deleteLater()
            except: pass
            self.effect_label = None

    def play_start_bgm(self, music_path='start_bgm.mp3'):
        try:
            url = QUrl.fromLocalFile(music_path)
            if url.isValid():
                self.start_bgm_player.setMedia(QMediaContent(url)); self.start_bgm_player.setVolume(50); self.start_bgm_player.play()
                self.start_bgm_player.mediaStatusChanged.connect(self.start_bgm_finished)
        except:
            pass

    def start_bgm_finished(self, status):
        if status == QMediaPlayer.EndOfMedia:
            self.play_main_bgm()

    def play_main_bgm(self, music_path='main_bgm.mp3'):
        try:
            url = QUrl.fromLocalFile(music_path)
            if url.isValid():
                self.playlist_main_bgm.clear(); self.playlist_main_bgm.addMedia(QMediaContent(url)); self.playlist_main_bgm.setPlaybackMode(QMediaPlaylist.Loop)
                self.main_bgm_player.setPlaylist(self.playlist_main_bgm); self.main_bgm_player.setVolume(20); self.main_bgm_player.play()
        except:
            pass

    def handle_sound_finished(self, status):
        try:
            if self.sound_player.media().canonicalUrl() == self.out_song:
                self.main_bgm_player.play()
        except:
            pass

# ======================
# 메인 실행
# ======================
if __name__ == '__main__':
    app = QApplication(sys.argv)

    start_intro = IntroScreen()
    start_intro.showFullScreen()

    sys.exit(app.exec_())
