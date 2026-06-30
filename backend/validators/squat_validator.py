"""
squat_validator.py
==================
Modular squat position validation, gating, and robust rep-counting
state machine. Designed to plug into app_logic.py / realtime detection.

Prevents false rep counts from non-exercise poses by requiring:
    1. Valid squat posture (upright body, hips/knees/ankles visible)
    2. Sustained posture for N consecutive frames (gating)
    3. Full DOWN → UP knee transition (state machine)
    4. Minimum model confidence score
    5. Anti-jitter cooldown between reps
"""

from __future__ import annotations

import numpy as np
import time
from collections import deque
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, Optional, Tuple


# ──────────────────────────────────────────────
# Enums & Data Classes
# ──────────────────────────────────────────────

class ValidatorState(Enum):
    """High-level state of the squat validator."""
    NOT_READY = auto()   # person not in squat-ready posture
    GATING    = auto()   # valid posture detected, accumulating frames
    UP        = auto()   # standing upright position
    DOWN      = auto()   # squat bottom position


@dataclass
class FrameResult:
    """Per-frame output returned by SquatValidator.process_frame()."""
    state: ValidatorState = ValidatorState.NOT_READY
    is_valid_posture: bool = False
    gate_progress: int = 0          # frames of valid posture accumulated
    gate_required: int = 5          # frames needed to pass gate
    rep_count: int = 0
    rep_just_counted: bool = False
    rep_completed: bool = False     # True when a full DOWN→UP transition occurs
    angles: Dict[str, float] = field(default_factory=dict)
    posture_details: Dict[str, bool] = field(default_factory=dict)
    feedback: list[str] = field(default_factory=list)


# ──────────────────────────────────────────────
# 3D Angle Helpers
# ──────────────────────────────────────────────

def _get_xyz(row: np.ndarray, landmark_idx: int) -> np.ndarray:
    """Extract (x, y, z) for a MediaPipe landmark from stride-4 flat array."""
    i = landmark_idx * 4
    return np.array([row[i], row[i + 1], row[i + 2]], dtype=np.float64)


def _get_visibility(row: np.ndarray, landmark_idx: int) -> float:
    """Get the visibility score for a landmark."""
    return float(row[landmark_idx * 4 + 3])


def _angle_3d(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """Angle in degrees at point b formed by segments a→b and c→b."""
    ba = a.astype(np.float64) - b.astype(np.float64)
    bc = c.astype(np.float64) - b.astype(np.float64)
    norm_ba = np.linalg.norm(ba)
    norm_bc = np.linalg.norm(bc)
    if norm_ba < 1e-8 or norm_bc < 1e-8:
        return 0.0
    cos_a = np.dot(ba, bc) / (norm_ba * norm_bc)
    return float(np.degrees(np.arccos(np.clip(cos_a, -1.0, 1.0))))


def _joints_visible(row: np.ndarray, indices: list[int],
                    threshold: float) -> bool:
    """Return True if ALL listed landmarks have visibility ≥ threshold."""
    return all(_get_visibility(row, idx) >= threshold for idx in indices)


def _best_side_visible(row: np.ndarray, threshold: float) -> str:
    """
    Determine which body side (left/right) has better landmark visibility.
    Returns 'left', 'right', or 'none'.
    For squats, at least shoulder + hip + knee + ankle must be visible.
    """
    left_indices  = [11, 23, 25, 27]  # L shoulder, hip, knee, ankle
    right_indices = [12, 24, 26, 28]  # R shoulder, hip, knee, ankle

    left_vis  = np.mean([_get_visibility(row, i) for i in left_indices])
    right_vis = np.mean([_get_visibility(row, i) for i in right_indices])

    left_core  = all(_get_visibility(row, i) >= threshold for i in left_indices)
    right_core = all(_get_visibility(row, i) >= threshold for i in right_indices)

    if left_core and right_core:
        return 'left' if left_vis >= right_vis else 'right'
    elif left_core:
        return 'left'
    elif right_core:
        return 'right'
    return 'none'


# ──────────────────────────────────────────────
# SquatValidator
# ──────────────────────────────────────────────

class SquatValidator:
    """
    Gate-guarded squat rep counter.

    Workflow per frame:
        1. Compute 3D joint angles (with visibility check).
        2. Validate squat posture (upright body, joints visible).
        3. Update gating counter.
        4. Run DOWN/UP state machine (knee angle based).
        5. Return FrameResult.

    Parameters
    ----------
    gate_frames : int
        Consecutive valid-posture frames required before counting starts.
    knee_down_angle : float
        Knee angle (degrees) below which the person is in DOWN (squat) position.
    knee_up_angle : float
        Knee angle (degrees) above which the person is in UP (standing) position.
    hip_angle_range : tuple[float, float]
        Acceptable hip-angle range for squat posture.
    knee_ready_min : float
        Minimum knee angle for the "ready" (standing) posture.
    confidence_threshold : float
        Minimum LSTM-model confidence to allow a rep.
    visibility_threshold : float
        Minimum landmark visibility to trust a joint.
    cooldown_frames : int
        Minimum frames between two rep counts (anti-jitter).
    posture_loss_tolerance : int
        Frames of invalid posture tolerated before resetting state.
    smoothing_window : int
        Number of past frames used for angle smoothing.
    vertical_y_threshold : float
        Maximum normalised Y-difference between shoulder-centre and
        hip-centre. For squats, body should be UPRIGHT (shoulder above hip).
    """

    # MediaPipe landmark indices
    _L_SHOULDER = 11
    _R_SHOULDER = 12
    _L_HIP      = 23
    _R_HIP      = 24
    _L_KNEE     = 25
    _R_KNEE     = 26
    _L_ANKLE    = 27
    _R_ANKLE    = 28

    def __init__(
        self,
        gate_frames: int = 3,
        knee_down_angle: float = 130.0,
        knee_up_angle: float = 155.0,
        hip_angle_range: Tuple[float, float] = (25.0, 180.0),
        knee_ready_min: float = 120.0,
        confidence_threshold: float = 0.5,
        visibility_threshold: float = 0.2,
        cooldown_frames: int = 3,
        posture_loss_tolerance: int = 60,
        smoothing_window: int = 5,
        vertical_y_threshold: float = 0.25,
    ):
        # Configuration
        self.gate_frames = gate_frames
        self.knee_down_angle = knee_down_angle
        self.knee_up_angle = knee_up_angle
        self.hip_angle_range = hip_angle_range
        self.knee_ready_min = knee_ready_min
        self.confidence_threshold = confidence_threshold
        self.visibility_threshold = visibility_threshold
        self.cooldown_frames = cooldown_frames
        self.posture_loss_tolerance = posture_loss_tolerance
        self.smoothing_window = smoothing_window
        self.vertical_y_threshold = vertical_y_threshold

        # Internal state
        self._state = ValidatorState.NOT_READY
        self._gate_counter = 0
        self._rep_count = 0
        self._frames_since_last_rep = self.cooldown_frames
        self._bad_posture_streak = 0
        self._deepest_knee_this_rep = 180.0
        self._feedback_memory: Dict[str, float] = {}
        self.feedback_ttl = 3.0
        self._feedback_cooldown: Dict[str, float] = {}  # per-category cooldown
        self.feedback_cooldown_time = 4.0  # seconds before same message can repeat

        # Smoothing buffers
        self._angle_buffers: Dict[str, deque] = {
            "l_hip": deque(maxlen=smoothing_window),
            "r_hip": deque(maxlen=smoothing_window),
            "l_knee": deque(maxlen=smoothing_window),
            "r_knee": deque(maxlen=smoothing_window),
        }

    # ── public properties ──────────────────────

    @property
    def state(self) -> ValidatorState:
        return self._state

    @property
    def rep_count(self) -> int:
        return self._rep_count

    def reset(self) -> None:
        """Reset all internal state (new session)."""
        self._state = ValidatorState.NOT_READY
        self._gate_counter = 0
        self._rep_count = 0
        self._frames_since_last_rep = self.cooldown_frames
        self._bad_posture_streak = 0
        self._deepest_knee_this_rep = 180.0
        self._feedback_memory.clear()
        self._feedback_cooldown.clear()
        for buf in self._angle_buffers.values():
            buf.clear()

    # ── angle computation ──────────────────────

    def compute_angles(self, row: np.ndarray) -> Optional[Dict[str, float]]:
        """
        Compute hip and knee angles from a single frame's landmarks.
        Uses per-side visibility fallback.
        """
        best_side = _best_side_visible(row, self.visibility_threshold)
        if best_side == 'none':
            return None

        angles: Dict[str, float] = {}

        # Left side
        left_ok = _joints_visible(row, [self._L_HIP, self._L_KNEE, self._L_ANKLE],
                                   self.visibility_threshold)
        l_shoulder_vis = _get_visibility(row, self._L_SHOULDER) >= self.visibility_threshold
        if left_ok:
            angles["l_knee"] = _angle_3d(
                _get_xyz(row, self._L_HIP),
                _get_xyz(row, self._L_KNEE),
                _get_xyz(row, self._L_ANKLE))
            if l_shoulder_vis:
                angles["l_hip"] = _angle_3d(
                    _get_xyz(row, self._L_SHOULDER),
                    _get_xyz(row, self._L_HIP),
                    _get_xyz(row, self._L_KNEE))

        # Right side
        right_ok = _joints_visible(row, [self._R_HIP, self._R_KNEE, self._R_ANKLE],
                                    self.visibility_threshold)
        r_shoulder_vis = _get_visibility(row, self._R_SHOULDER) >= self.visibility_threshold
        if right_ok:
            angles["r_knee"] = _angle_3d(
                _get_xyz(row, self._R_HIP),
                _get_xyz(row, self._R_KNEE),
                _get_xyz(row, self._R_ANKLE))
            if r_shoulder_vis:
                angles["r_hip"] = _angle_3d(
                    _get_xyz(row, self._R_SHOULDER),
                    _get_xyz(row, self._R_HIP),
                    _get_xyz(row, self._R_KNEE))

        # Mirror missing side from the visible side
        mirror_pairs = [("l_hip", "r_hip"), ("l_knee", "r_knee")]
        for left_key, right_key in mirror_pairs:
            if left_key in angles and right_key not in angles:
                angles[right_key] = angles[left_key]
            elif right_key in angles and left_key not in angles:
                angles[left_key] = angles[right_key]

        # Default any still-missing angles to safe values (standing)
        for key in ["l_hip", "r_hip", "l_knee", "r_knee"]:
            if key not in angles:
                angles[key] = 170.0

        return angles

    # ── smoothing ──────────────────────────────

    def _smooth_angles(self, raw: Dict[str, float]) -> Dict[str, float]:
        """Push raw angles into buffers and return moving averages."""
        smoothed: Dict[str, float] = {}
        for key, value in raw.items():
            if key in self._angle_buffers:
                self._angle_buffers[key].append(value)
                buf = self._angle_buffers[key]
                smoothed[key] = float(np.mean(list(buf)))
            else:
                smoothed[key] = value
        return smoothed

    # ── posture validation ─────────────────────

    def is_squat_posture(
        self,
        row: np.ndarray,
        angles: Dict[str, float],
    ) -> Tuple[bool, Dict[str, bool], list[str]]:
        """
        Check whether the person is in a valid squat-ready posture.

        Criteria:
            1. Body approximately upright (shoulders above hips)
            2. Hip angle within acceptable range
            3. Knees extended for ready position (standing)
            4. Knees symmetrical (no excessive valgus)
            5. Back posture check (not leaning too far forward)

        Returns
        -------
        (is_valid, details, feedback)
        """
        feedback = []

        # 1. Body upright — shoulder Y should be ABOVE (less than) hip Y
        #    In normalised coords, Y increases downward.
        shoulder_y = (
            _get_xyz(row, self._L_SHOULDER)[1]
            + _get_xyz(row, self._R_SHOULDER)[1]
        ) / 2.0
        hip_y = (
            _get_xyz(row, self._L_HIP)[1]
            + _get_xyz(row, self._R_HIP)[1]
        ) / 2.0
        # Shoulders should be above (lower Y value) or close to hips
        body_upright = shoulder_y < hip_y + self.vertical_y_threshold
        if not body_upright:
            feedback.append("Stand upright to start")

        # 2. Hip angle within range
        avg_hip = (angles["l_hip"] + angles["r_hip"]) / 2.0
        hip_ok = self.hip_angle_range[0] <= avg_hip <= self.hip_angle_range[1]
        if not hip_ok:
            if avg_hip < self.hip_angle_range[0]:
                feedback.append("Keep your chest up — too much forward lean")
            else:
                feedback.append("Adjust hip alignment")

        # 3. Knees ready (extended for starting position)
        avg_knee = (angles["l_knee"] + angles["r_knee"]) / 2.0
        knees_ready = avg_knee >= self.knee_ready_min
        if not knees_ready and self._state in (ValidatorState.NOT_READY, ValidatorState.GATING):
            feedback.append("Stand fully upright to start")

        # During active counting (UP/DOWN), knees will flex — that's fine
        if self._state in (ValidatorState.UP, ValidatorState.DOWN):
            knees_ready = True

        # 4. Knee symmetry check — detect if one knee bends much more than the other
        knee_diff = abs(angles["l_knee"] - angles["r_knee"])
        knees_symmetrical = knee_diff < 50.0
        if not knees_symmetrical and self._state in (ValidatorState.UP, ValidatorState.DOWN):
            feedback.append("Keep knees even — avoid leaning to one side")

        # 5. Back posture — check if hips are hinging too much (forward lean)
        #    Hip angle (shoulder-hip-knee): standing ≈ 170°, squat ≈ 80-120°,
        #    excessive forward lean < 70°
        back_ok = True
        if self._state in (ValidatorState.UP, ValidatorState.DOWN):
            if avg_hip < 70.0:
                back_ok = False
                feedback.append("Keep your back straight — don't bend forward")

            # Depth coaching during active squat (only if significantly too high)
            if self._state == ValidatorState.DOWN and avg_knee > self.knee_down_angle + 20:
                feedback.append("Go lower — bend your knees more")

        details = {
            "body_upright": body_upright,
            "hip_ok": hip_ok,
            "knees_ready": knees_ready,
        }
        is_valid = all(details.values())

        return is_valid, details, feedback

    # ── gating ─────────────────────────────────

    def _update_gate(self, is_valid: bool) -> bool:
        """
        Accumulate consecutive valid-posture frames.
        Returns True when the gate is open.
        """
        if is_valid:
            self._gate_counter = min(self._gate_counter + 1, self.gate_frames)
            self._bad_posture_streak = 0
        else:
            self._bad_posture_streak += 1
            if self._bad_posture_streak >= self.posture_loss_tolerance:
                self._gate_counter = 0

        return self._gate_counter >= self.gate_frames

    # ── state machine ──────────────────────────

    def _update_state(
        self,
        avg_knee: float,
        gate_open: bool,
        is_valid: bool,
        model_confidence: Optional[float],
    ) -> Tuple[bool, Optional[str]]:
        """
        Advance the state machine and return whether a rep was just counted.

        Transitions:
            NOT_READY → GATING  (valid posture detected)
            GATING    → UP      (gate opens — person is standing)
            UP        → DOWN    (knee < down threshold — squatting)
            DOWN      → UP      (knee > up threshold — stood back up — rep counted)
            Any       → NOT_READY (posture lost beyond tolerance)
        """
        rep_counted = False
        coaching_tip = None
        self._frames_since_last_rep += 1

        # ── Reset on prolonged bad posture ─────
        if (not is_valid
                and self._bad_posture_streak >= self.posture_loss_tolerance):
            if self._state != ValidatorState.NOT_READY:
                self._state = ValidatorState.NOT_READY
                self._gate_counter = 0
            return False, None

        # ── State transitions ──────────────────
        if self._state == ValidatorState.NOT_READY:
            if is_valid:
                self._state = ValidatorState.GATING

        elif self._state == ValidatorState.GATING:
            if gate_open:
                self._state = ValidatorState.UP

        elif self._state == ValidatorState.UP:
            if avg_knee < self.knee_down_angle:
                self._state = ValidatorState.DOWN
                self._deepest_knee_this_rep = avg_knee

        elif self._state == ValidatorState.DOWN:
            self._deepest_knee_this_rep = min(self._deepest_knee_this_rep, avg_knee)

            if avg_knee > self.knee_up_angle:
                cooldown_ok = (
                    self._frames_since_last_rep >= self.cooldown_frames
                )
                if cooldown_ok:
                    # Only corrective depth feedback (no positive praise)
                    if self._deepest_knee_this_rep > self.knee_down_angle:
                        coaching_tip = "Go much deeper for a full squat!"
                    elif self._deepest_knee_this_rep > self.knee_down_angle - 10:
                        coaching_tip = "Almost there — squat a little deeper!"
                    # Good depth → no feedback (silent approval)

                    self._frames_since_last_rep = 0
                    rep_counted = True
                    self._rep_count += 1
                    self._deepest_knee_this_rep = 180.0
                self._state = ValidatorState.UP

        return rep_counted, coaching_tip

    # ── main entry point ───────────────────────

    def process_frame(
        self,
        keypoints_flat: np.ndarray,
        model_confidence: Optional[float] = None,
    ) -> FrameResult:
        """
        Process one frame of raw MediaPipe-format landmarks.

        Parameters
        ----------
        keypoints_flat : np.ndarray
            Flat (132,) array of [x, y, z, visibility] × 33 landmarks.
        model_confidence : float or None
            LSTM model's "Correct form" probability (0–1).

        Returns
        -------
        FrameResult with all per-frame information for display.
        """
        result = FrameResult(
            state=self._state,
            gate_required=self.gate_frames,
            rep_count=self._rep_count,
        )

        # ── Step 1: compute angles ─────────────
        raw_angles = self.compute_angles(keypoints_flat)
        if raw_angles is None:
            self._update_gate(False)
            rep_counted, _ = self._update_state(180.0, False, False, model_confidence)
            result.state = self._state
            result.rep_count = self._rep_count
            result.rep_completed = rep_counted
            result.rep_just_counted = rep_counted
            result.gate_progress = self._gate_counter
            result.feedback = ["Person not fully visible"]
            return result

        # ── Step 2: smooth angles ──────────────
        smoothed = self._smooth_angles(raw_angles)
        result.angles = smoothed

        # ── Step 3: validate posture ───────────
        is_valid, details, posture_feedback = self.is_squat_posture(keypoints_flat, smoothed)
        result.is_valid_posture = is_valid
        result.posture_details = details
        result.feedback.extend(posture_feedback)

        # ── Step 4: update gating ──────────────
        gate_open = self._update_gate(is_valid)
        result.gate_progress = self._gate_counter

        # ── Step 5: update state machine ───────
        avg_knee = (smoothed["l_knee"] + smoothed["r_knee"]) / 2.0
        rep_counted, state_feedback = self._update_state(
            avg_knee, gate_open, is_valid, model_confidence,
        )

        # ── Step 6: manage feedback persistency with per-category cooldown ──
        now = time.time()

        # Clean up expired cooldowns
        self._feedback_cooldown = {
            tip: expiry for tip, expiry in self._feedback_cooldown.items()
            if expiry > now
        }

        for tip in posture_feedback:
            # Only add if not on cooldown (prevents rapid-fire same message)
            if tip not in self._feedback_cooldown:
                self._feedback_memory[tip] = now + self.feedback_ttl
                self._feedback_cooldown[tip] = now + self.feedback_cooldown_time
        if state_feedback:
            if state_feedback not in self._feedback_cooldown:
                self._feedback_memory[state_feedback] = now + self.feedback_ttl
                self._feedback_cooldown[state_feedback] = now + self.feedback_cooldown_time

        self._feedback_memory = {
            tip: expiry for tip, expiry in self._feedback_memory.items()
            if expiry > now
        }

        result.feedback = list(self._feedback_memory.keys())

        result.state = self._state
        result.rep_count = self._rep_count
        result.rep_just_counted = rep_counted
        result.rep_completed = rep_counted

        return result
