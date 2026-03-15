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


def generate_level(size: int, max_folds: int, colors: list,
                   front_density: float = 0.2, back_density: float = 0.3,
                   max_solutions: int = 5, min_target_cells: int = 2,
                   require_transfer: bool = False,
                   attempts: int = 5000) -> Optional[Dict]:
    """
    Generate a random level with desired properties.
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


# ── Level generation tiers ──────────────────────────────────────────────

TIER_CONFIGS = [
    # Tier 1: Single fold basics (levels 1-10)
    {"size": 4, "max_folds": 1, "colors": [1], "front_d": 0.3, "back_d": 0.3,
     "max_sols": 3, "min_cells": 3, "transfer": False, "count": 10},

    # Tier 2: Single fold, 2 colors (levels 11-16)
    {"size": 4, "max_folds": 1, "colors": [1, 2], "front_d": 0.3, "back_d": 0.3,
     "max_sols": 2, "min_cells": 4, "transfer": False, "count": 6},

    # Tier 3: Two folds, basic (levels 17-26)
    {"size": 4, "max_folds": 2, "colors": [1, 2], "front_d": 0.1, "back_d": 0.3,
     "max_sols": 4, "min_cells": 3, "transfer": False, "count": 10},

    # Tier 4: Two folds, 3 colors (levels 27-34)
    {"size": 4, "max_folds": 2, "colors": [1, 2, 3], "front_d": 0.15, "back_d": 0.3,
     "max_sols": 3, "min_cells": 4, "transfer": False, "count": 8},

    # Tier 5: Two folds with transfer (levels 35-44)
    {"size": 4, "max_folds": 2, "colors": [1, 2], "front_d": 0.3, "back_d": 0.25,
     "max_sols": 4, "min_cells": 3, "transfer": True, "count": 10},

    # Tier 6: Three folds (levels 45-56)
    {"size": 4, "max_folds": 3, "colors": [1, 2, 3], "front_d": 0.15, "back_d": 0.25,
     "max_sols": 6, "min_cells": 3, "transfer": False, "count": 12},

    # Tier 7: Three folds with transfer (levels 57-68)
    {"size": 4, "max_folds": 3, "colors": [1, 2, 3], "front_d": 0.25, "back_d": 0.25,
     "max_sols": 5, "min_cells": 4, "transfer": True, "count": 12},

    # Tier 8: Four folds (levels 69-78)
    {"size": 4, "max_folds": 4, "colors": [1, 2, 3], "front_d": 0.2, "back_d": 0.2,
     "max_sols": 8, "min_cells": 3, "transfer": True, "count": 10},

    # Tier 9: 5×5 grid, 2 folds (levels 79-86)
    {"size": 5, "max_folds": 2, "colors": [1, 2], "front_d": 0.15, "back_d": 0.25,
     "max_sols": 4, "min_cells": 4, "transfer": False, "count": 8},

    # Tier 10: 5×5 grid, 3 folds with transfer (levels 87-100)
    {"size": 5, "max_folds": 3, "colors": [1, 2, 3], "front_d": 0.2, "back_d": 0.2,
     "max_sols": 6, "min_cells": 4, "transfer": True, "count": 14},
]

TIER_NAMES = {
    1: ["初折", "轻触", "半边", "投影", "拼图", "窗帘", "色带", "阶梯", "框架", "对称"],
    2: ["双色", "棋格", "条纹", "拼贴", "波纹", "交错"],
    3: ["双折", "夹心", "信封", "角落", "十字", "扇面", "层叠", "回形", "阶梯", "门框"],
    4: ["三彩", "调色", "虹桥", "拼花", "星芒", "织锦", "彩带", "花窗"],
    5: ["暗渡", "潜行", "偷梁", "换日", "移花", "接木", "转身", "腾挪", "借道", "穿越"],
    6: ["三折", "曲径", "迂回", "绕行", "迷踪", "连环", "套叠", "盘旋", "螺旋", "弯曲", "蜿蜒", "盘绕"],
    7: ["暗流", "潜龙", "蛰伏", "蜕变", "涅槃", "逆转", "倒影", "镜像", "折射", "衍射", "干涉", "共振"],
    8: ["万象", "千变", "百转", "九曲", "八卦", "七巧", "六合", "五行", "四象", "太极"],
    9: ["广场", "庭院", "花园", "长廊", "回廊", "天井", "中庭", "殿堂"],
    10: ["星河", "银河", "星云", "星座", "北斗", "南斗", "天狼", "织女", "牛郎", "嫦娥", "后羿", "夸父", "精卫", "女娲"],
}


def generate_all_levels(seed=42):
    """Generate all 100 levels across all tiers."""
    random.seed(seed)
    all_levels = []
    level_id = 1
    tier_idx = 0

    for tier_config in TIER_CONFIGS:
        tier_idx += 1
        names = TIER_NAMES[tier_idx]
        generated = 0

        for i in range(tier_config["count"]):
            # Try multiple seeds to get variety
            for attempt in range(20):
                result = generate_level(
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

        print(f"--- Tier {tier_idx}: generated {generated}/{tier_config['count']} ---")

    return all_levels


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "verify":
        filename = sys.argv[2] if len(sys.argv) > 2 else "data/levels.json"
        verify_all_levels(filename)
    elif len(sys.argv) > 1 and sys.argv[1] == "generate":
        seed = int(sys.argv[2]) if len(sys.argv) > 2 else 42
        levels = generate_all_levels(seed)
        output = {"levels": levels}
        with open("data/levels.json", "w") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        print(f"\nGenerated {len(levels)} levels -> data/levels.json")
    else:
        print("Usage:")
        print("  python3 tools/level_generator.py verify [file]")
        print("  python3 tools/level_generator.py generate [seed]")
