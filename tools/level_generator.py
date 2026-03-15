#!/usr/bin/env python3
"""
Origami Puzzle level generator & verifier.
Simulates the fold mechanic (with front-to-back transfer) and
generates levels with desired difficulty properties.
"""
import json
import copy
import itertools
import random
import sys
from typing import List, Tuple, Optional, Dict

EMPTY = 0

# Quadrant indices: T=0, R=1, B=2, L=3
def cell_to_quads(cell):
    if isinstance(cell, list):
        return list(cell)
    return [cell, cell, cell, cell]

def normalize_cell(quads):
    if quads[0] == quads[1] == quads[2] == quads[3]:
        return quads[0]
    return quads

def merge_quads(existing, incoming):
    return [incoming[i] if incoming[i] != EMPTY else existing[i] for i in range(4)]

TRANSFORMS = {
    "v": lambda q: [q[0], q[3], q[2], q[1]],
    "h": lambda q: [q[2], q[1], q[0], q[3]],
    "d_bs": lambda q: [q[3], q[2], q[1], q[0]],
    "d_fs": lambda q: [q[1], q[0], q[3], q[2]],
}

def transform_cell(cell, fold_type):
    return TRANSFORMS[fold_type](cell_to_quads(cell))


def fold_grid(front: List[List[int]], back: List[List[int]], size: int,
              is_vertical: bool, fold_pos: int) -> Tuple[List[List[int]], List[List[int]]]:
    """Perform a single fold, returning new (front, back)."""
    f = copy.deepcopy(front)
    b = copy.deepcopy(back)

    if is_vertical:
        left = fold_pos
        right = size - fold_pos
        fold_left = left <= right
        if fold_left:
            cols = range(fold_pos)
        else:
            cols = range(fold_pos, size)
        for col in cols:
            mirror = 2 * fold_pos - 1 - col
            if mirror < 0 or mirror >= size:
                continue
            for row in range(size):
                if f[row][col] != EMPTY:
                    b[row][mirror] = f[row][col]
                if back[row][col] != EMPTY:  # use original back, not mutated
                    f[row][mirror] = back[row][col]
                f[row][col] = EMPTY
                b[row][col] = EMPTY
    else:
        top = fold_pos
        bottom = size - fold_pos
        fold_top = top <= bottom
        if fold_top:
            rows = range(fold_pos)
        else:
            rows = range(fold_pos, size)
        for row in rows:
            mirror = 2 * fold_pos - 1 - row
            if mirror < 0 or mirror >= size:
                continue
            for col in range(size):
                if f[row][col] != EMPTY:
                    b[mirror][col] = f[row][col]
                if back[row][col] != EMPTY:
                    f[mirror][col] = back[row][col]
                f[row][col] = EMPTY
                b[row][col] = EMPTY
    return f, b


def apply_folds(front, back, size, fold_sequence):
    """Apply a sequence of folds. Each fold is (is_vertical, fold_pos)."""
    f, b = copy.deepcopy(front), copy.deepcopy(back)
    for is_v, pos in fold_sequence:
        f, b = fold_grid(f, b, size, is_v, pos)
    return f, b


def fold_diagonal(front, back, size, fold_type, offset):
    """Perform a diagonal fold, returning new (front, back)."""
    f = copy.deepcopy(front)
    b = copy.deepcopy(back)
    orig_f = copy.deepcopy(front)
    orig_b = copy.deepcopy(back)
    is_bs = (fold_type == "d_bs")

    for row in range(size):
        for col in range(size):
            val = col - row if is_bs else col + row
            if (is_bs and val > offset) or (not is_bs and val < offset):
                # Source cell
                if is_bs:
                    tr, tc = col - offset, row + offset
                else:
                    tr, tc = offset - col, offset - row
                if tr < 0 or tr >= size or tc < 0 or tc >= size:
                    f[row][col] = EMPTY
                    b[row][col] = EMPTY
                    continue
                src_f_xf = transform_cell(orig_f[row][col], fold_type)
                src_b_xf = transform_cell(orig_b[row][col], fold_type)
                tgt_b = cell_to_quads(b[tr][tc])
                b[tr][tc] = normalize_cell(merge_quads(tgt_b, src_f_xf))
                tgt_f = cell_to_quads(f[tr][tc])
                f[tr][tc] = normalize_cell(merge_quads(tgt_f, src_b_xf))
                f[row][col] = EMPTY
                b[row][col] = EMPTY
            elif val == offset:
                # Fold line cell
                src_quads = [0, 1] if is_bs else [0, 3]  # T,R or T,L
                of = cell_to_quads(orig_f[row][col])
                ob = cell_to_quads(orig_b[row][col])
                inc_f = [of[i] if i in src_quads else EMPTY for i in range(4)]
                inc_b = [ob[i] if i in src_quads else EMPTY for i in range(4)]
                xf_f = transform_cell(inc_f, fold_type)
                xf_b = transform_cell(inc_b, fold_type)
                cur_b = cell_to_quads(b[row][col])
                b[row][col] = normalize_cell(merge_quads(cur_b, xf_f))
                cur_f = cell_to_quads(f[row][col])
                f[row][col] = normalize_cell(merge_quads(cur_f, xf_b))
                ff = cell_to_quads(f[row][col])
                fb = cell_to_quads(b[row][col])
                for qi in src_quads:
                    ff[qi] = EMPTY
                    fb[qi] = EMPTY
                f[row][col] = normalize_cell(ff)
                b[row][col] = normalize_cell(fb)
    return f, b


def fold_grid_any(front, back, size, fold_def):
    """Perform any fold type from a fold definition dict."""
    ft = fold_def["type"]
    if ft in ("v", "h"):
        pos = fold_def["pos"]
        return fold_grid(front, back, size, ft == "v", pos)
    else:
        return fold_diagonal(front, back, size, ft, fold_def["offset"])


def apply_folds_any(front, back, size, fold_sequence):
    """Apply a sequence of fold defs."""
    f, b = copy.deepcopy(front), copy.deepcopy(back)
    for fold_def in fold_sequence:
        f, b = fold_grid_any(f, b, size, fold_def)
    return f, b


def check_win(front, target, size):
    for r in range(size):
        for c in range(size):
            fq = cell_to_quads(front[r][c])
            tq = cell_to_quads(target[r][c])
            if fq != tq:
                return False
    return True


def all_fold_defs(size, include_diag=False):
    """列出所有可能的折叠定义"""
    folds = []
    for pos in range(1, size):
        folds.append({"type": "v", "pos": pos})
        folds.append({"type": "h", "pos": pos})
    if include_diag:
        for offset in range(-(size - 2), size - 1):
            folds.append({"type": "d_bs", "offset": offset})
        for offset in range(1, 2 * (size - 1)):
            folds.append({"type": "d_fs", "offset": offset})
    return folds


def all_any_fold_sequences(fold_defs, max_folds):
    """生成所有可能的折叠序列（基于给定的折叠定义列表）"""
    return list(itertools.product(fold_defs, repeat=max_folds))


def all_fold_sequences(size: int, max_folds: int):
    """Generate all possible fold sequences up to max_folds length."""
    fold_options = []
    for pos in range(1, size):
        fold_options.append((True, pos))   # vertical
        fold_options.append((False, pos))  # horizontal

    for length in range(1, max_folds + 1):
        for seq in itertools.product(fold_options, repeat=length):
            yield list(seq)


def find_solutions(front, back, target, size, max_folds, fold_defs=None):
    """寻找所有有效解（支持 V/H 和对角折叠）"""
    if fold_defs is None:
        fold_defs = all_fold_defs(size, include_diag=False)
    solutions = []
    for seq in itertools.product(fold_defs, repeat=max_folds):
        seq = list(seq)
        f, _ = apply_folds_any(front, back, size, seq)
        if f == target:
            solutions.append(seq)
    return solutions


def find_minimal_solutions(front, back, target, size, max_folds, fold_defs=None):
    """寻找恰好使用 max_folds 步的解（无更短解存在）"""
    if fold_defs is None:
        fold_defs = all_fold_defs(size, include_diag=False)
    # 检查是否有更短的解
    for k in range(1, max_folds):
        if find_solutions(front, back, target, size, k, fold_defs):
            return []  # 存在更短解，不返回
    return find_solutions(front, back, target, size, max_folds, fold_defs)


def fmt_fold(fold):
    if isinstance(fold, dict):
        ft = fold["type"]
        if ft in ("v", "h"):
            return f"{ft.upper()}@{fold['pos']}"
        else:
            return f"{ft}@{fold['offset']}"
    direction = "V" if fold[0] else "H"
    return f"{direction}@{fold[1]}"


def fmt_sequence(seq):
    return " → ".join(fmt_fold(f) for f in seq)


def empty_grid(size):
    return [[0] * size for _ in range(size)]


def random_grid(size, colors, density=0.3):
    """Generate a random grid with given colors and approximate density."""
    grid = empty_grid(size)
    for r in range(size):
        for c in range(size):
            if random.random() < density:
                grid[r][c] = random.choice(colors)
    return grid


def grid_complexity(grid, size):
    """Count non-empty cells."""
    return sum(1 for r in range(size) for c in range(size) if grid[r][c] != EMPTY)


# ── Quality Scoring ─────────────────────────────────────────────────

def visual_change_score(front, target, size):
    """视觉变化度评分 (0-30)"""
    total_quads = size * size * 4
    changed = 0
    for r in range(size):
        for c in range(size):
            fq = cell_to_quads(front[r][c])
            tq = cell_to_quads(target[r][c])
            changed += sum(1 for i in range(4) if fq[i] != tq[i])
    ratio = changed / total_quads

    # 变化比例得分 (0-20)
    if 0.3 <= ratio <= 0.7:
        ratio_score = 20
    elif ratio < 0.1 or ratio > 0.9:
        ratio_score = 5
    else:
        ratio_score = 12

    # 对称性加分 (0-10)
    sym_score = 0
    if _is_h_symmetric(target, size):
        sym_score += 4
    if _is_v_symmetric(target, size):
        sym_score += 3
    if _is_rot180_symmetric(target, size):
        sym_score += 3

    return ratio_score + sym_score


def _is_h_symmetric(grid, size):
    for r in range(size):
        for c in range(size // 2):
            if cell_to_quads(grid[r][c]) != cell_to_quads(grid[r][size - 1 - c]):
                return False
    return True


def _is_v_symmetric(grid, size):
    for r in range(size // 2):
        for c in range(size):
            if cell_to_quads(grid[r][c]) != cell_to_quads(grid[size - 1 - r][c]):
                return False
    return True


def _is_rot180_symmetric(grid, size):
    for r in range(size):
        for c in range(size):
            if cell_to_quads(grid[r][c]) != cell_to_quads(grid[size - 1 - r][size - 1 - c]):
                return False
    return True


def complexity_score(solutions, front, back, size):
    """解题复杂度评分 (0-40)"""
    score = 0
    sol = solutions[0]

    # 顺序依赖 (0-20)
    if len(sol) >= 2:
        base_f, _ = apply_folds_any(front, back, size, sol)
        order_matters = False
        for perm in itertools.islice(itertools.permutations(sol), 120):
            pf, _ = apply_folds_any(front, back, size, list(perm))
            if pf != base_f:
                order_matters = True
                break
        score += 20 if order_matters else 3

    # 背面转移 (0-10)
    f_copy, b_copy = copy.deepcopy(front), copy.deepcopy(back)
    for fold_def in sol:
        old_front = copy.deepcopy(f_copy)
        f_copy, b_copy = fold_grid_any(f_copy, b_copy, size, fold_def)
        for r in range(size):
            for c in range(size):
                fq_old = cell_to_quads(old_front[r][c])
                fq_new = cell_to_quads(f_copy[r][c])
                bq = cell_to_quads(back[r][c])
                for i in range(4):
                    if fq_new[i] != 0 and fq_old[i] == 0 and bq[i] != 0:
                        score += 10
                        break
                else:
                    continue
                break
            else:
                continue
            break

    # 折叠多样性 (0-10)
    fold_types = set(f["type"] for f in sol)
    score += min(len(fold_types) * 4, 10)

    # 惩罚: 全部相同折叠 (-5)
    if len(sol) >= 2 and len(set(str(f) for f in sol)) == 1:
        score -= 5

    return max(score, 0)


def _count_matching(front, target, size):
    """统计正面与目标的象限匹配数"""
    match = 0
    for r in range(size):
        for c in range(size):
            fq = cell_to_quads(front[r][c])
            tq = cell_to_quads(target[r][c])
            match += sum(1 for i in range(4) if fq[i] == tq[i])
    return match


def _greedy_solve(front, back, target, fold_defs, max_folds, size):
    """贪心求解：每步选匹配目标最多的折叠"""
    sf, sb = copy.deepcopy(front), copy.deepcopy(back)
    sol = []
    for _ in range(max_folds):
        best_fold, best_match = None, -1
        for f in fold_defs:
            tf, tb = copy.deepcopy(sf), copy.deepcopy(sb)
            tf, tb = fold_grid_any(tf, tb, size, f)
            m = _count_matching(tf, target, size)
            if m > best_match:
                best_match = m
                best_fold = f
        if best_fold is None:
            return None
        sf, sb = fold_grid_any(sf, sb, size, best_fold)
        sol.append(best_fold)
    if sf == target:
        return sol
    return None


def non_obvious_score(front, back, target, fold_defs, solutions, size):
    """非显而易见性评分 (0-30)"""
    score = 0
    sol = solutions[0]

    # 贪心求解 (0-20)
    greedy = _greedy_solve(front, back, target, fold_defs, len(sol), size)
    if greedy is None:
        score += 20
    elif greedy != sol:
        score += 10

    # 反直觉首步 (0-10)
    initial_match = _count_matching(front, target, size)
    after_f, _ = apply_folds_any(front, back, size, [sol[0]])
    first_match = _count_matching(after_f, target, size)
    if first_match < initial_match:
        score += 10
    elif first_match == initial_match:
        score += 3

    return score


def quality_score(front, back, target, fold_defs, solutions, size):
    """总体质量评分 (0-100)"""
    vs = visual_change_score(front, target, size)
    cs = complexity_score(solutions, front, back, size)
    ns = non_obvious_score(front, back, target, fold_defs, solutions, size)
    return vs + cs + ns


def generate_level_legacy(size: int, max_folds: int, colors: list,
                          front_density: float = 0.2, back_density: float = 0.3,
                          max_solutions: int = 5, min_target_cells: int = 2,
                          require_transfer: bool = False,
                          attempts: int = 5000) -> Optional[Dict]:
    """
    Legacy: Generate a random level with desired properties (V/H only, tuple-based).
    Returns dict with front, back, target, solution or None.
    """
    for _ in range(attempts):
        front = random_grid(size, colors, front_density)
        back = random_grid(size, colors, back_density)

        # Try all fold sequences to find which targets are reachable
        target_map = {}  # target_hash -> (target, sequences)
        for seq in all_fold_sequences(size, max_folds):
            if len(seq) != max_folds:
                continue
            f, _ = apply_folds(front, back, size, seq)
            key = str(f)
            if key not in target_map:
                target_map[key] = (copy.deepcopy(f), [])
            target_map[key][1].append(seq)

        # Find targets that aren't solvable in fewer folds
        for key, (target, seqs) in target_map.items():
            tc = grid_complexity(target, size)
            if tc < min_target_cells:
                continue

            # Check no shorter solution
            shorter = find_solutions(front, back, target, size, max_folds - 1) if max_folds > 1 else []
            if shorter:
                continue

            num_sols = len(seqs)
            if num_sols > max_solutions:
                continue

            # If require_transfer, check that at least one fold has non-empty front in source
            if require_transfer:
                has_transfer = False
                f_test, b_test = copy.deepcopy(front), copy.deepcopy(back)
                for is_v, pos in seqs[0]:
                    # Check if source zone has non-empty front
                    if is_v:
                        left = pos
                        right = size - pos
                        if left <= right:
                            src_cols = range(pos)
                        else:
                            src_cols = range(pos, size)
                        for c in src_cols:
                            for r in range(size):
                                if f_test[r][c] != EMPTY:
                                    has_transfer = True
                    else:
                        top = pos
                        bottom = size - pos
                        if top <= bottom:
                            src_rows = range(pos)
                        else:
                            src_rows = range(pos, size)
                        for r in src_rows:
                            for c in range(size):
                                if f_test[r][c] != EMPTY:
                                    has_transfer = True
                    f_test, b_test = fold_grid(f_test, b_test, size, is_v, pos)
                if not has_transfer:
                    continue

            return {
                "front": front,
                "back": back,
                "target": target,
                "size": size,
                "max_folds": max_folds,
                "solutions": seqs,
                "num_solutions": num_sols
            }
    return None


def generate_level(size, max_folds, colors, front_density=0.2,
                   back_density=0.3, max_solutions=3, min_target_cells=2,
                   require_transfer=False, fold_defs=None, min_quality=60,
                   attempts=5000):
    """
    生成单个关卡。
    fold_defs: 可用折叠定义列表。None = 仅 V/H（向后兼容）
    min_quality: 最低质量评分（0=不检查）
    """
    if fold_defs is None:
        fold_defs = all_fold_defs(size, include_diag=False)

    for _ in range(attempts):
        front = random_grid(size, colors, front_density)
        back = random_grid(size, colors, back_density)

        target_map = {}
        # 枚举所有 max_folds 长度的序列
        for seq in itertools.product(fold_defs, repeat=max_folds):
            seq = list(seq)
            f, _ = apply_folds_any(front, back, size, seq)
            key = str(f)
            if key not in target_map:
                target_map[key] = (f, [seq])
            else:
                target_map[key][1].append(seq)

        for key, (target, seqs) in target_map.items():
            # 过滤: 非空目标
            non_zero = sum(1 for r in target for c in r
                          if (c if not isinstance(c, list) else max(c)) != 0)
            if non_zero < min_target_cells:
                continue
            # 过滤: 解数限制
            if len(seqs) > max_solutions:
                continue
            # 过滤: 不能用更少步骤解决
            has_shorter = False
            for k in range(1, max_folds):
                for short_seq in itertools.product(fold_defs, repeat=k):
                    sf, _ = apply_folds_any(front, back, size, list(short_seq))
                    if sf == target:
                        has_shorter = True
                        break
                if has_shorter:
                    break
            if has_shorter:
                continue
            # 过滤: 背面转移
            if require_transfer:
                has_t = False
                for seq in seqs[:1]:
                    tf, tb = copy.deepcopy(front), copy.deepcopy(back)
                    for fold_def in seq:
                        old_f = copy.deepcopy(tf)
                        tf, tb = fold_grid_any(tf, tb, size, fold_def)
                        for r in range(size):
                            for ci in range(size):
                                for qi in range(4):
                                    nv = cell_to_quads(tf[r][ci])[qi]
                                    ov = cell_to_quads(old_f[r][ci])[qi]
                                    if nv != 0 and ov == 0:
                                        has_t = True
                if not has_t:
                    continue
            # 过滤: 质量评分
            if min_quality > 0:
                qs = quality_score(front, back, target, fold_defs, seqs, size)
                if qs < min_quality:
                    continue
            else:
                qs = 0

            return {
                "front": front,
                "back": back,
                "target": target,
                "solutions": seqs,
                "quality": qs,
            }
    return None


def verify_level(level_data: dict) -> bool:
    """Verify a level from JSON data has at least one solution."""
    front = level_data["front"]
    back = level_data["back"]
    target = level_data["target"]
    size = level_data["size"]
    max_folds = level_data["max_folds"]
    folds = level_data.get("folds", None)

    if folds:
        # Try all permutations of available folds up to max_folds
        sols = []
        for length in range(1, max_folds + 1):
            for seq in itertools.product(folds, repeat=length):
                f, _ = apply_folds_any(front, back, size, list(seq))
                if check_win(f, target, size):
                    sols.append(list(seq))
        return len(sols) > 0, sols
    else:
        sols = find_solutions(front, back, target, size, max_folds)
        return len(sols) > 0, sols


def verify_all_levels(filename):
    """Verify all levels in a JSON file."""
    with open(filename) as f:
        data = json.load(f)

    for level in data["levels"]:
        valid, sols = verify_level(level)
        min_folds = min(len(s) for s in sols) if sols else 0
        status = "✓" if valid else "✗"
        print(f"Level {level['id']:3d} \"{level['name']}\": {status} "
              f"({len(sols)} solutions, min {min_folds} folds)")
        if sols:
            # Show first solution
            print(f"         Solution: {fmt_sequence(sols[0])}")


# ── Chapter configs (10 chapters × 10 levels) ─────────────────────────

CHAPTER_CONFIGS = [
    # Ch1: 单折单色入门
    {"chapter": 1, "ids": range(1, 11), "size": 4, "max_folds": 1,
     "colors": [1], "front_d": 0.3, "back_d": 0.3,
     "max_sols": 3, "min_cells": 2, "transfer": False,
     "include_diag": False, "min_quality": 40},
    # Ch2: 双折入门
    {"chapter": 2, "ids": range(11, 21), "size": 4, "max_folds": 2,
     "colors": [1, 2], "front_d": 0.3, "back_d": 0.3,
     "max_sols": 3, "min_cells": 3, "transfer": False,
     "include_diag": False, "min_quality": 50},
    # Ch3: 双折多色
    {"chapter": 3, "ids": range(21, 31), "size": 4, "max_folds": 2,
     "colors": [1, 2, 3], "front_d": 0.25, "back_d": 0.3,
     "max_sols": 3, "min_cells": 3, "transfer": False,
     "include_diag": False, "min_quality": 55},
    # Ch4: 对角初遇
    {"chapter": 4, "ids": range(31, 41), "size": 4, "max_folds": 2,
     "colors": [1, 2, 3], "front_d": 0.25, "back_d": 0.25,
     "max_sols": 3, "min_cells": 3, "transfer": False,
     "include_diag": True, "diag_ratio": 0.4, "min_quality": 55},
    # Ch5: 对角组合
    {"chapter": 5, "ids": range(41, 51), "size": 4, "max_folds": 3,
     "colors": [1, 2, 3], "front_d": 0.2, "back_d": 0.25,
     "max_sols": 3, "min_cells": 3, "transfer": False,
     "include_diag": True, "diag_ratio": 0.4, "max_fold_defs": 8,
     "min_quality": 55},
    # Ch6: 三折挑战
    {"chapter": 6, "ids": range(51, 61), "size": 4, "max_folds": 3,
     "colors": [1, 2, 3], "front_d": 0.2, "back_d": 0.25,
     "max_sols": 3, "min_cells": 4, "transfer": True,
     "include_diag": True, "diag_ratio": 0.35, "max_fold_defs": 8,
     "min_quality": 60},
    # Ch7: 新色登场
    {"chapter": 7, "ids": range(61, 71), "size": 4, "max_folds": 4,
     "colors": [1, 2, 3, 4], "front_d": 0.2, "back_d": 0.2,
     "max_sols": 3, "min_cells": 4, "transfer": True,
     "include_diag": True, "diag_ratio": 0.3, "max_fold_defs": 8,
     "min_quality": 60},
    # Ch8: 大网格入门
    {"chapter": 8, "ids": range(71, 81), "size": 5, "max_folds": 3,
     "colors": [1, 2, 3], "front_d": 0.2, "back_d": 0.25,
     "max_sols": 3, "min_cells": 4, "transfer": False,
     "include_diag": True, "diag_ratio": 0.3, "max_fold_defs": 8,
     "min_quality": 55},
    # Ch9: 大网格进阶
    {"chapter": 9, "ids": range(81, 91), "size": 5, "max_folds": 4,
     "colors": [1, 2, 3, 4], "front_d": 0.2, "back_d": 0.2,
     "max_sols": 3, "min_cells": 5, "transfer": True,
     "include_diag": True, "diag_ratio": 0.3, "max_fold_defs": 8,
     "min_quality": 60},
    # Ch10: 终极挑战
    {"chapter": 10, "ids": range(91, 101), "size": 5, "max_folds": 4,
     "colors": [1, 2, 3, 4, 5], "front_d": 0.2, "back_d": 0.2,
     "max_sols": 3, "min_cells": 4, "transfer": False,
     "include_diag": True, "diag_ratio": 0.3, "max_fold_defs": 8,
     "min_quality": 55},
]

CHAPTER_NAMES = {
    1: ["初折", "倒影", "箭头", "钻石", "窄边", "角落", "点缀", "棋盘", "波纹", "拼合"],
    2: ["双条", "三明治", "信封", "L形", "阶梯", "回声", "涟漪", "交错", "并排", "叠影"],
    3: ["彩虹", "棱镜", "调色", "织锦", "花砖", "拼图", "斑斓", "绚彩", "万花", "画卷"],
    4: ["斜阳", "棱角", "锐角", "折扇", "菱形", "三角", "楔子", "尖峰", "偏转", "交叉"],
    5: ["旋涡", "螺旋", "回旋", "漩流", "暗涌", "潮汐", "激流", "湍急", "奔涌", "翻转"],
    6: ["迷宫", "暗渡", "曲径", "幽径", "蜿蜒", "通幽", "转角", "回廊", "陷阱", "破局"],
    7: ["紫韵", "霓虹", "极光", "彩霞", "幻彩", "琉璃", "水晶", "宝石", "虹光", "星辰"],
    8: ["开阔", "疆域", "天地", "无垠", "广袤", "原野", "平原", "高原", "丘陵", "山峦"],
    9: ["征途", "攀登", "跋涉", "远眺", "凌云", "穿越", "探索", "拓荒", "先驱", "巅峰"],
    10: ["终焉", "觉醒", "涅槃", "超越", "永恒", "圆满", "大成", "极致", "归一", "万象"],
}

# Legacy tier configs (kept for backward compatibility)
TIER_CONFIGS = CHAPTER_CONFIGS
TIER_NAMES = CHAPTER_NAMES


def generate_all_levels_legacy(seed=42):
    """Legacy: Generate all 100 levels across all tiers (V/H only)."""
    random.seed(seed)
    all_levels = []
    level_id = 1
    tier_idx = 0

    for tier_config in CHAPTER_CONFIGS:
        tier_idx += 1
        names = CHAPTER_NAMES[tier_idx]
        generated = 0

        for i in range(len(tier_config["ids"])):
            # Try multiple seeds to get variety
            for attempt in range(20):
                result = generate_level_legacy(
                    size=tier_config["size"],
                    max_folds=tier_config["max_folds"],
                    colors=tier_config["colors"],
                    front_density=tier_config["front_d"],
                    back_density=tier_config["back_d"],
                    max_solutions=tier_config["max_sols"],
                    min_target_cells=tier_config["min_cells"],
                    require_transfer=tier_config["transfer"],
                    attempts=8000,
                )
                if result:
                    name = names[i % len(names)]
                    if i >= len(names):
                        name = f"{name}{i // len(names) + 1}"

                    level = {
                        "id": level_id,
                        "name": name,
                        "size": result["size"],
                        "max_folds": result["max_folds"],
                        "front": result["front"],
                        "back": result["back"],
                        "target": result["target"],
                    }
                    all_levels.append(level)
                    sol_str = fmt_sequence(result["solutions"][0])
                    print(f"Level {level_id:3d} \"{name}\" "
                          f"(size={result['size']}, folds={result['max_folds']}, "
                          f"sols={result['num_solutions']}): {sol_str}")
                    level_id += 1
                    generated += 1
                    break
            else:
                print(f"WARNING: Could not generate level {level_id} for tier {tier_idx}", file=sys.stderr)
                # Create a placeholder
                level_id += 1

        print(f"--- Tier {tier_idx}: generated {generated}/{len(tier_config['ids'])} ---")

    return all_levels


def generate_all_levels(seed=42):
    """生成全部 100 关"""
    from handcrafted_levels import HANDCRAFTED
    random.seed(seed)
    levels = []

    for ch_cfg in CHAPTER_CONFIGS:
        chapter = ch_cfg["chapter"]
        size = ch_cfg["size"]
        max_folds = ch_cfg["max_folds"]
        colors = ch_cfg["colors"]
        include_diag = ch_cfg.get("include_diag", False)
        diag_ratio = ch_cfg.get("diag_ratio", 0)
        max_fold_defs = ch_cfg.get("max_fold_defs", None)
        min_quality = ch_cfg.get("min_quality", 0)

        names = CHAPTER_NAMES[chapter]
        name_idx = 0

        for level_id in ch_cfg["ids"]:
            # 手工关卡
            if level_id in HANDCRAFTED:
                lv = HANDCRAFTED[level_id]
                lv_data = {
                    "id": level_id,
                    "name": lv["name"],
                    "size": lv["size"],
                    "max_folds": lv["max_folds"],
                    "front": lv["front"],
                    "back": lv["back"],
                    "target": lv["target"],
                }
                if "folds" in lv:
                    lv_data["folds"] = lv["folds"]
                levels.append(lv_data)
                print(f"  Level {level_id}: {lv['name']} (handcrafted)", flush=True)
                name_idx += 1
                continue

            # 生成关卡
            # 决定是否包含对角折叠
            use_diag = include_diag and random.random() < diag_ratio
            fold_defs = all_fold_defs(size, include_diag=use_diag)

            # 大网格限制折线数
            if max_fold_defs and len(fold_defs) > max_fold_defs:
                fold_defs = random.sample(fold_defs, max_fold_defs)

            # 为章节前几关调整折叠数
            pos_in_chapter = level_id - ch_cfg["ids"].start
            if pos_in_chapter < 4:
                folds = max(1, max_folds - 1) if max_folds > 1 else max_folds
            else:
                folds = max_folds

            # 根据搜索空间大小调整尝试次数
            search_space = len(fold_defs) ** folds
            if search_space > 10000:
                gen_attempts = 500
            elif search_space > 1000:
                gen_attempts = 2000
            else:
                gen_attempts = 5000

            result = generate_level(
                size=size, max_folds=folds, colors=colors,
                front_density=ch_cfg["front_d"], back_density=ch_cfg["back_d"],
                max_solutions=ch_cfg["max_sols"], min_target_cells=ch_cfg["min_cells"],
                require_transfer=ch_cfg["transfer"], fold_defs=fold_defs,
                min_quality=min_quality, attempts=gen_attempts,
            )

            if result is None:
                # 降低质量要求重试
                result = generate_level(
                    size=size, max_folds=folds, colors=colors,
                    front_density=ch_cfg["front_d"], back_density=ch_cfg["back_d"],
                    max_solutions=ch_cfg["max_sols"] + 2,
                    min_target_cells=max(1, ch_cfg["min_cells"] - 1),
                    require_transfer=False, fold_defs=fold_defs,
                    min_quality=0, attempts=gen_attempts,
                )

            if result is None:
                raise RuntimeError(f"Level {level_id}: FAILED to generate after all attempts!")

            name = names[name_idx] if name_idx < len(names) else f"关卡{level_id}"
            lv_data = {
                "id": level_id,
                "name": name,
                "size": size,
                "max_folds": folds,
                "front": result["front"],
                "back": result["back"],
                "target": result["target"],
            }
            # 包含对角的关卡需要 folds 字段
            if use_diag or chapter >= 4:
                lv_data["folds"] = fold_defs

            levels.append(lv_data)
            print(f"  Level {level_id}: {name} (generated, quality={result['quality']})", flush=True)
            name_idx += 1

    return levels


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 level_generator.py <command>")
        print("  verify [file]        - Verify levels in JSON file")
        print("  generate-all [seed]  - Generate all 100 levels")
        print("  generate [seed]      - Alias for generate-all")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "verify":
        filename = sys.argv[2] if len(sys.argv) > 2 else "data/levels.json"
        verify_all_levels(filename)
    elif cmd in ("generate-all", "generate"):
        seed = int(sys.argv[2]) if len(sys.argv) > 2 else 42
        print(f"Generating 100 levels (seed={seed})...")
        levels = generate_all_levels(seed)
        output = {"levels": levels}
        with open("data/levels.json", "w") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        print(f"\nGenerated {len(levels)} levels -> data/levels.json")
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
