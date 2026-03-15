# 100 关卡设计规范

## 概述

为折纸益智游戏设计 100 个关卡，从入门到终极挑战，形成完整的难度曲线。采用分层策略：20 关手工设计（教学关 + boss 关），80 关由生成器批量生成并经质量评估筛选。

现有 26 关全部弃用，100 关从零开始设计。

## 设计决策

- **对角折叠比重**：~20-25%（约 20-25 关），从第 4 章开始引入
- **网格尺寸**：4×4 为主，第 8 章起引入 5×5
- **最大折叠次数**：最高 6 次（仅最终章最后几关）
- **难度曲线**：波浪式——整体递增，每章开头是休息关，章内由易到难
- **颜色**：前 6 章用 1-3 色（珊瑚红、薄荷绿、琥珀黄），第 7 章起扩充到 4-5 色
- **生成方式**：手工设计关键节点 + 生成器批量填充 + 质量评估筛选

## 章节结构

100 关分为 10 章，每章 10 关。章节表中的折叠数和颜色数为**填充关卡的范围**；教学关（第 1 关）可低于该范围以降低门槛。

| 章 | 关卡 | 网格 | 折叠数 | 颜色 | 折叠类型 | 主题 |
|:--:|:----:|:----:|:------:|:----:|:-------:|:----:|
| 1 | 1-10 | 4×4 | 1 | 1 | V/H | 入门：单折单色 |
| 2 | 11-20 | 4×4 | 1-2 | 1-2 | V/H | 进阶：双折入门 |
| 3 | 21-30 | 4×4 | 2 | 2-3 | V/H | 双折 + 多色 |
| 4 | 31-40 | 4×4 | 2-3 | 3 | V/H + 引入对角 | 对角初遇 |
| 5 | 41-50 | 4×4 | 2-3 | 3 | V/H + 对角 | 对角组合 |
| 6 | 51-60 | 4×4 | 3 | 3 | V/H + 对角 | 三折挑战 |
| 7 | 61-70 | 4×4 | 3-4 | 3-4 | 全类型 | 新色登场 |
| 8 | 71-80 | 5×5 | 2-3 | 3 | V/H + 对角 | 大网格入门 |
| 9 | 81-90 | 5×5 | 3-4 | 4 | 全类型 | 大网格进阶 |
| 10 | 91-100 | 5×5 | 4-6 | 4-5 | 全类型 | 终极挑战 |

### 每章内部结构

- **第 1 关（休息/教学关）**：手工设计。引入该章新机制，难度低于前一章结尾。折叠数/颜色数可低于章节表范围。
- **第 2-9 关（填充关）**：生成器产出，经质量评估筛选，难度逐步递增。
- **第 10 关（boss 关）**：手工设计。该章最高难度，需要综合运用本章所有机制。

### 对角折叠分布

- 第 1-3 章（关卡 1-30）：纯 V/H，不含对角
- 第 4 章（关卡 31-40）：引入对角折叠，约 3-4 关含对角
- 第 5-6 章（关卡 41-60）：每章约 3-4 关含对角
- 第 7-10 章（关卡 61-100）：每章约 2-3 关含对角
- 总计约 20-25 关涉及对角折叠

### 对角折叠 offset 有效范围

- `d_bs`（\方向）：`offset = col - row`，有效范围 `[-(size-2), size-2]`
  - 4×4：offset ∈ {-2, -1, 0, 1, 2}
  - 5×5：offset ∈ {-3, -2, -1, 0, 1, 2, 3}
- `d_fs`（/方向）：`offset = col + row`，有效范围 `[1, 2*(size-1)-1]`
  - 4×4：offset ∈ {1, 2, 3, 4, 5}
  - 5×5：offset ∈ {1, 2, 3, 4, 5, 6, 7}

## 颜色扩展

现有 COLOR_MAP（0-3）：
- 0：`#F5F0E8`（背景/空）
- 1：`#E8785A`（珊瑚红）
- 2：`#6ABEAB`（薄荷绿）
- 3：`#E8B84A`（琥珀黄）

第 7 章起新增：
- 4：`#7B6CB7`（薰衣草紫）——与现有三色对比鲜明
- 5：`#5BA4CF`（天空蓝）——仅最终章使用

颜色使用规则：
- 第 1 章：仅用色 1
- 第 2-3 章：用色 1-2
- 第 4-6 章：用色 1-3
- 第 7-9 章：用色 1-4
- 第 10 章：用色 1-5

## 关卡质量评估系统

### 必要条件（不过则淘汰）

1. **可解性**：至少存在一个解法
2. **最优性**：不能用更少折叠次数达成目标（强制用满 max_folds）
3. **少解性**：解法数量 ≤ 3，避免"随便折都能过"

### 趣味性评分（0-100 分，阈值 ≥ 60 入选）

#### 视觉变化度（0-30 分）

比较 `front`（初始正面）和 `target`（目标正面），逐格逐象限对比：

```python
def visual_change_score(front, target, size):
    total_quads = size * size * 4
    changed = 0
    for r in range(size):
        for c in range(size):
            fq = cell_to_quads(front[r][c])
            tq = cell_to_quads(target[r][c])
            changed += sum(1 for i in range(4) if fq[i] != tq[i])
    change_ratio = changed / total_quads  # 0.0 ~ 1.0

    # 变化比例得分 (0-20): 30%-70% 最佳，过低或过高扣分
    if 0.3 <= change_ratio <= 0.7:
        ratio_score = 20
    elif change_ratio < 0.1 or change_ratio > 0.9:
        ratio_score = 5
    else:
        ratio_score = 12

    # 对称性加分 (0-10): 检查水平/垂直/旋转对称
    sym_score = 0
    if is_h_symmetric(target): sym_score += 4
    if is_v_symmetric(target): sym_score += 3
    if is_rotational_symmetric(target): sym_score += 3

    return ratio_score + sym_score
```

#### 解题复杂度（0-40 分）

```python
def complexity_score(solutions, fold_defs, front, back, size):
    score = 0
    sol = solutions[0]  # 取第一个解

    # 顺序依赖 (0-15): 测试解法的所有排列，看结果是否相同
    if len(sol) >= 2:
        base_result = apply_folds(front, back, sol, size)
        order_matters = False
        for perm in itertools.permutations(sol):
            if apply_folds(front, back, list(perm), size) != base_result:
                order_matters = True
                break
        score += 15 if order_matters else 3

    # 背面转移 (0-10): 解法中是否有折叠导致背面非零内容出现在正面
    has_transfer = any(involves_back_transfer(fold, front, back, size) for fold in sol)
    score += 10 if has_transfer else 0

    # 折叠多样性 (0-10): 解法中使用了几种不同类型的折叠
    fold_types = set(f["type"] for f in sol)
    score += min(len(fold_types) * 4, 10)

    # 惩罚: 所有折叠沿同一条线 (-5)
    if len(sol) >= 2 and len(set(str(f) for f in sol)) == 1:
        score -= 5

    return max(score, 0)
```

#### 非显而易见性（0-30 分）

"贪心策略"定义：每步选择使正面与目标匹配格数最多的折叠。

```python
def non_obvious_score(front, back, target, fold_defs, solutions, size):
    score = 0
    sol = solutions[0]

    # 贪心求解 (0-20): 贪心是否能找到正确解
    greedy_sol = greedy_solve(front, back, target, fold_defs, len(sol), size)
    if greedy_sol is None:
        score += 20  # 贪心完全失败
    elif greedy_sol != sol:
        score += 10  # 贪心找到不同解

    # 反直觉首步 (0-10): 第一步折叠后匹配度是否下降
    initial_match = count_matching(front, target, size)
    after_first = apply_folds(front, back, [sol[0]], size)
    first_match = count_matching(after_first, target, size)
    if first_match < initial_match:
        score += 10  # 第一步让情况"变差"
    elif first_match == initial_match:
        score += 3

    return score

def greedy_solve(front, back, target, fold_defs, max_folds, size):
    """贪心：每步选匹配目标格数最多的折叠"""
    state_front, state_back = deep_copy(front), deep_copy(back)
    sol = []
    for _ in range(max_folds):
        best_fold = None
        best_match = -1
        for f in fold_defs:
            test_f, test_b = deep_copy(state_front), deep_copy(state_back)
            apply_single_fold(test_f, test_b, f, size)
            m = count_matching(test_f, target, size)
            if m > best_match:
                best_match = m
                best_fold = f
        if best_fold is None:
            return None
        apply_single_fold(state_front, state_back, best_fold, size)
        sol.append(best_fold)
    if state_front == target:
        return sol
    return None

def count_matching(front, target, size):
    """逐象限统计匹配数"""
    match = 0
    for r in range(size):
        for c in range(size):
            fq = cell_to_quads(front[r][c])
            tq = cell_to_quads(target[r][c])
            match += sum(1 for i in range(4) if fq[i] == tq[i])
    return match
```

### 生成流水线

```
每章: 生成 500+ 候选 → 可解性过滤 → 最优性过滤 → 少解过滤 → 趣味性评分 → 排序 → 取 top 8 填充
```

### 5×5 大网格搜索策略

5×5 网格 + 高折叠数时，暴力枚举所有折叠序列不可行（折叠选项 ~16+，6 折 = ~1600 万序列）。采用以下策略：

1. **限制可用折线数量**：每关的 `folds` 字段最多包含 8 条可用折线（从全部 V/H/对角中随机选取），将搜索空间控制在 8^6 ≈ 262,144
2. **随机采样验证**：生成候选时不枚举全部解，而是随机采样 10,000 个折叠序列寻找解法。找到解法后再用限定折线集做完整验证
3. **渐进式生成**：先生成 4 折候选，验证通过后部分提升为 5-6 折（在已有解法基础上添加"干扰折线"增加复杂度）

## 手工设计关卡清单（20 关）

以下关卡由人工精心设计，每关有明确的设计意图。教学关的折叠数可低于章节表范围。

| 关卡 | 角色 | 折叠数 | 设计意图 |
|:----:|:----:|:------:|:--------|
| 1 | 教学 | 1 | 第一次折叠。单色单折 V，最简镜像 |
| 10 | Boss | 1 | 单折总结：需要从多条折线中选择唯一正确的位置 |
| 11 | 教学 | 2 | 引入双折概念：两次简单 V 折 |
| 20 | Boss | 2 | 双折综合：V+H 组合，需要正确顺序 |
| 21 | 教学 | 2 | 引入第 3 种颜色，简单双折 |
| 30 | Boss | 2 | 多色双折：3 色交织，顺序关键 |
| 31 | 教学 | 1 | 第一次对角折叠（d_bs），纯单折教学 |
| 40 | Boss | 3 | V/H + 对角混合三折 |
| 41 | 教学 | 2 | 对角组合入门：一次对角 + 一次 V/H |
| 50 | Boss | 3 | 对角 + V/H 三折，需利用背面转移 |
| 51 | 教学 | 3 | 三折入门：简单的三步 V/H 序列 |
| 60 | Boss | 3 | 三折极致：顺序依赖 + 背面转移 |
| 61 | 教学 | 2 | 引入第 4 种颜色，简单双折 |
| 70 | Boss | 4 | 4 色 + 全类型折叠的四折挑战 |
| 71 | 教学 | 2 | 第一个 5×5 关卡，简单双折 V/H |
| 80 | Boss | 3 | 5×5 三折 + 对角 |
| 81 | 教学 | 2 | 5×5 + 4 色入门，简单双折 |
| 90 | Boss | 4 | 5×5 四折全类型 |
| 91 | 教学 | 3 | 终极章入门：5×5 三折复习 |
| 100 | Boss | 6 | 终极关：5×5 六折，5 色，全类型折叠 |

## 实现要点

### 生成器扩展

1. **支持对角折叠生成**：`generate_level()` 需扩展为可随机选择 V/H/对角折线，为关卡分配 `folds` 字段。当前 `all_fold_sequences()` 仅枚举 V/H，需新增对角枚举
2. **支持 5×5 网格**：验证器/求解器已支持任意尺寸，生成器参数需扩展
3. **支持 4-5 色**：颜色参数范围从 `[1,2,3]` 扩展到 `[1,2,3,4,5]`
4. **质量评估模块**：实现上述三项评分函数，集成到生成流水线
5. **批量生成 CLI**：新增 `generate-all` 子命令，按章节配置批量生成，输出 `levels.json`

### 游戏代码修改

1. **COLOR_MAP 扩展**：新增颜色 4（`#7B6CB7` 薰衣草紫）和 5（`#5BA4CF` 天空蓝）
2. **levels.json 替换**：用生成的 100 关数据替换现有内容

### 输出格式

每关 JSON 结构不变：
```json
{
  "id": 1,
  "name": "关卡名",
  "size": 4,
  "max_folds": 1,
  "front": [[...]],
  "back": [[...]],
  "target": [[...]],
  "folds": [{"type": "v", "pos": 2}]
}
```

第 1-3 章的纯 V/H 关卡可省略 `folds` 字段（向后兼容，自动生成所有 V+H 折线）。第 4 章起所有关卡必须显式指定 `folds`。
