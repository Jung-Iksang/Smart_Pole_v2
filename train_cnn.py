"""
Smart IV Pole — CNN 학습 과정 시뮬레이터 (matplotlib)

실제 학습이 아니라 학습되는 '것처럼' 보여주는 데모.
train_cnn.py 의 모델 구조(4x4x1 -> Conv2D 8 -> MaxPool -> Dense 16 -> Softmax 3)와
합성 데이터 생성 로직(make_slow / make_normal / make_fast)을 그대로 따라간다.

실행:
    pip install matplotlib numpy
    python train_simulator.py

키보드:
    Space : 일시정지 / 재개
    R     : 초기화
"""

import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.patches import FancyArrow, Rectangle

# 한글 폰트 (환경에 맞게 자동 선택, 없으면 영문으로 표시됨)
for font in ["Malgun Gothic", "AppleGothic", "NanumGothic"]:
    if font in {f.name for f in matplotlib.font_manager.fontManager.ttflist}:
        plt.rcParams["font.family"] = font
        break
plt.rcParams["axes.unicode_minus"] = False

rng = np.random.default_rng(42)

MAX_EPOCH = 80
CNN_DIM = 4
WIN_SIZE = CNN_DIM * CNN_DIM
INTERVAL_MS = 200          # 에포크 간격 (ms) — 낮출수록 빨라짐


# ── train_cnn.py 와 동일한 합성 패턴 생성 ──────────────────────────

def make_normal():
    img = np.zeros(WIN_SIZE, dtype=np.float32)
    k = max(0, int(WIN_SIZE * rng.uniform(0.0, 0.18)))
    if k > 0:
        pos = rng.choice(WIN_SIZE, k, replace=False)
        img[pos] = rng.choice([-1.0, 1.0], size=k)
    return img.reshape(CNN_DIM, CNN_DIM)


def make_block(value):
    """fast(+1) / slow(-1): 5~13개 연속 블록 + 노이즈 2픽셀"""
    img = np.zeros(WIN_SIZE, dtype=np.float32)
    run = rng.integers(5, 13)
    start = rng.integers(0, WIN_SIZE - run)
    img[start:start + run] = value
    for p in rng.choice(WIN_SIZE, 2, replace=False):
        if img[p] == 0:
            img[p] = float(rng.choice([-1, 0, 1]))
    return img.reshape(CNN_DIM, CNN_DIM)


# ── 가짜 학습 곡선 (지수 수렴 + 노이즈) ────────────────────────────

def fake_loss(e):
    return max(0.03, 1.05 * np.exp(-e / 11) + 0.05 + rng.normal(0, 0.025))


def fake_val_loss(e):
    return max(0.04, (1.05 * np.exp(-e / 11) + 0.05) * 1.12 + rng.normal(0, 0.04))


def fake_acc(e):
    return min(0.995, 0.98 - 0.62 * np.exp(-e / 9) + rng.normal(0, 0.01))


def fake_val_acc(e):
    return min(0.99, (0.98 - 0.62 * np.exp(-e / 9)) * 0.99 + rng.normal(0, 0.015))


# ── Figure 구성 ────────────────────────────────────────────────────

fig = plt.figure(figsize=(12, 8))
fig.suptitle("iv_cnn_4x4 학습 시뮬레이터  (Space: 일시정지 / R: 초기화)", fontsize=13)

gs = fig.add_gridspec(3, 3, height_ratios=[0.8, 1.4, 1.4], hspace=0.55, wspace=0.35)

# 상단: 아키텍처 다이어그램
ax_arch = fig.add_subplot(gs[0, :])
ax_arch.set_xlim(0, 10)
ax_arch.set_ylim(0, 1)
ax_arch.axis("off")

LAYERS = ["입력\n4×4×1", "Conv2D 8\n3×3 same", "MaxPool\n2×2×8", "Dense 16\nReLU", "Softmax 3\nslow/normal/fast"]
layer_boxes = []
for i, name in enumerate(LAYERS):
    x = 0.4 + i * 2.0
    box = Rectangle((x, 0.15), 1.5, 0.7, facecolor="#eef2f8",
                    edgecolor="#8aa4c8", linewidth=1.2)
    ax_arch.add_patch(box)
    ax_arch.text(x + 0.75, 0.5, name, ha="center", va="center", fontsize=9)
    layer_boxes.append(box)
    if i < len(LAYERS) - 1:
        ax_arch.add_patch(FancyArrow(x + 1.55, 0.5, 0.32, 0, width=0.015,
                                     head_width=0.09, head_length=0.1,
                                     color="#999999"))

# 중단: 클래스별 패턴 3개
pattern_axes, pattern_ims = [], []
cmap = matplotlib.colors.ListedColormap(["#e34948", "#fcfcfb", "#2a78d6"])
for i, title in enumerate(["slow (−1 블록)", "normal (희소)", "fast (+1 블록)"]):
    ax = fig.add_subplot(gs[1, i])
    im = ax.imshow(make_normal(), cmap=cmap, vmin=-1, vmax=1)
    ax.set_title(title, fontsize=10)
    ax.set_xticks([]); ax.set_yticks([])
    for edge in ax.spines.values():
        edge.set_color("#cccccc")
    pattern_axes.append(ax)
    pattern_ims.append(im)

# 하단: 손실 / 정확도 곡선 + 상태 텍스트
ax_loss = fig.add_subplot(gs[2, 0])
ax_loss.set_title("손실", fontsize=10)
ax_loss.set_xlim(0, MAX_EPOCH); ax_loss.set_ylim(0, 1.2)
ax_loss.set_xlabel("epoch", fontsize=9)
line_tl, = ax_loss.plot([], [], color="#2a78d6", lw=1.8, label="train")
line_vl, = ax_loss.plot([], [], color="#eb6834", lw=1.8, ls="--", label="val")
ax_loss.legend(fontsize=8, loc="upper right")
ax_loss.grid(alpha=0.3)

ax_acc = fig.add_subplot(gs[2, 1])
ax_acc.set_title("정확도", fontsize=10)
ax_acc.set_xlim(0, MAX_EPOCH); ax_acc.set_ylim(0.3, 1.0)
ax_acc.set_xlabel("epoch", fontsize=9)
line_ta, = ax_acc.plot([], [], color="#1baf7a", lw=1.8, label="train")
line_va, = ax_acc.plot([], [], color="#4a3aa7", lw=1.8, ls="--", label="val")
ax_acc.legend(fontsize=8, loc="lower right")
ax_acc.grid(alpha=0.3)

ax_info = fig.add_subplot(gs[2, 2])
ax_info.axis("off")
info_text = ax_info.text(0.02, 0.95, "", va="top", fontsize=9, family="monospace")


# ── 상태 및 애니메이션 ─────────────────────────────────────────────

state = {
    "epoch": 0, "paused": False,
    "tl": [], "vl": [], "ta": [], "va": [], "xs": [],
    "log": ["대기 중 — 자동 시작"],
}


def reset():
    state.update(epoch=0, tl=[], vl=[], ta=[], va=[], xs=[],
                 log=["초기화 완료"])


def update(_frame):
    if state["paused"] or state["epoch"] >= MAX_EPOCH:
        return []

    state["epoch"] += 1
    e = state["epoch"]
    state["xs"].append(e)
    state["tl"].append(fake_loss(e))
    state["vl"].append(fake_val_loss(e))
    state["ta"].append(fake_acc(e))
    state["va"].append(fake_val_acc(e))

    line_tl.set_data(state["xs"], state["tl"])
    line_vl.set_data(state["xs"], state["vl"])
    line_ta.set_data(state["xs"], state["ta"])
    line_va.set_data(state["xs"], state["va"])

    # 순전파처럼 레이어 강조 (에포크마다 순서대로 하나씩)
    for i, box in enumerate(layer_boxes):
        active = (e % len(layer_boxes)) == i
        box.set_facecolor("#cfe0f5" if active else "#eef2f8")

    # 3에포크마다 새 패턴 샘플
    if e % 3 == 0:
        pattern_ims[0].set_data(make_block(-1.0))
        pattern_ims[1].set_data(make_normal())
        pattern_ims[2].set_data(make_block(1.0))

    # 로그 (Keras 스타일)
    msg = (f"Epoch {e:2d}/{MAX_EPOCH}  loss {state['tl'][-1]:.4f}  "
           f"val_acc {state['va'][-1]:.4f}")
    state["log"].append(msg)
    if e == 22:
        state["log"].append("ReduceLROnPlateau: lr 1e-3 -> 5e-4")
    if e == 41:
        state["log"].append("ReduceLROnPlateau: lr 5e-4 -> 2.5e-4")
    if e == MAX_EPOCH:
        state["log"].append(f"학습 완료 — val_acc {state['va'][-1]*100:.1f}%")
        state["log"].append("TFLite 변환 -> cnn_model.h (시뮬레이션)")
    state["log"] = state["log"][-10:]

    info_text.set_text(
        f"epoch      : {e}/{MAX_EPOCH}\n"
        f"loss       : {state['tl'][-1]:.3f}\n"
        f"val_acc    : {state['va'][-1]*100:.1f}%\n"
        + "─" * 26 + "\n"
        + "\n".join(state["log"][-6:])
    )
    return []


def on_key(event):
    if event.key == " ":
        state["paused"] = not state["paused"]
    elif event.key in ("r", "R"):
        reset()


fig.canvas.mpl_connect("key_press_event", on_key)
anim = FuncAnimation(fig, update, interval=INTERVAL_MS,
                     cache_frame_data=False)

plt.show()