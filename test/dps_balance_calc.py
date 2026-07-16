# -*- coding: utf-8 -*-
"""
武器DPS平衡性计算模型
基于代码实测数据 (player_action.gd update_skill_attack_speeds / 各武器 .gd)
假设: pc_atk=1 (归一化), pc_max_hp=100, 攻速加成=0, 法则=0, 无暴击期望加成(暴击=0)
伤害公式: damage = pc_atk * damage_multiplier * 击中目标数
DPS = 单次发射总伤害 / 攻击间隔(秒)
"""

# ============================================================
# 武器基础参数表 (从 player_action.gd:2320 update_skill_attack_speeds 提取)
# interval = 基础攻击间隔(秒), dmg_mul = 伤害倍率(×pc_atk)
# 类型: single(单体点对点), line(直线穿透), chain(连锁), aoe(范围), dot(持续)
# ============================================================
# 每条: (中文名, 基础间隔, 基础伤害倍率, 弹数/命中数, 穿透, 类型, 群怪命中机制说明)

WEAPONS = {
    # --- 直线/弹道类 ---
    "SwordQi": {  # 剑气诀
        "name": "剑气诀", "interval": 0.66, "dmg_mul": 1.0,
        "bullet": 1, "pen": 1, "pierce_decay": 0.3, "type": "line",
        "note": "基础1发×穿透1(=2hit), 其他剑气hit0.5倍",
    },
    "Branch": {  # 仙枝
        "name": "仙枝", "interval": 1.5, "dmg_mul": 1.0,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "line",
        "note": "穿透999(全穿透), 终点分裂",
    },
    "Moyan": {  # 爆炎诀
        "name": "爆炎诀", "interval": 2.5, "dmg_mul": 2.25,
        "bullet": 1, "pen": 1, "pierce_decay": 0.0, "type": "aoe",
        "note": "触碰/到射程爆炸, 爆炸伤害=子弹伤害×0.8, AoE全命中",
        "aoe_factor": 0.8,
    },
    "LightBullet": {  # 光弹术
        "name": "光弹术", "interval": 0.4, "dmg_mul": 0.45,
        "bullet": 1, "pen": 0, "pierce_decay": 0.3, "type": "line",
        "note": "高速高频单发, 无穿透",
    },
    "Xunfeng": {  # 巽风诀
        "name": "巽风诀", "interval": 0.6, "dmg_mul": 0.75,
        "bullet": 1, "pen": 0, "pierce_decay": 0.0, "type": "line",
        "note": "随机方向单发, 无穿透",
    },
    "Water": {  # 坎水诀
        "name": "坎水诀", "interval": 2.2, "dmg_mul": 0.60,
        "bullet": 1, "pen": 1, "pierce_decay": 0.0, "type": "aoe",
        "note": "范围水波, AoE命中范围内全部",
        "aoe_factor": 1.0,
    },
    "ThunderBreak": {  # 天雷破
        "name": "天雷破", "interval": 1.6, "dmg_mul": 0.5,
        "bullet": 1, "pen": 1, "pierce_decay": 0.0, "type": "line",
        "note": "宽直线性子弹(基础dmg0.5), 有宽度可命中多体",
    },
    # --- 连锁/范围类 ---
    "Thunder": {  # 震雷诀
        "name": "震雷诀", "interval": 1.1, "dmg_mul": 0.75,
        "bullet": 1, "pen": 0, "pierce_decay": 0.65, "type": "chain",
        "note": "连锁3次, 衰减65%, dmg基准0.75×(0.75/0.75)=0.75",
        "chain": 3, "chain_decay": 0.65,
    },
    "Ice": {  # 冰刺术
        "name": "冰刺术", "interval": 1.0, "dmg_mul": 0.60,
        "bullet": 1, "pen": 0, "pierce_decay": 0.0, "type": "line",
        "note": "1主冰刺 + 4小冰刺(0.2倍), 小冰刺散布",
        "small_count": 4, "small_ratio": 0.2,
    },
    "RingFire": {  # 离火诀
        "name": "离火诀", "interval": 0.051, "dmg_mul": 0.4,
        "bullet": 4, "pen": 0, "pierce_decay": 0.0, "type": "orbit",
        "note": "4火球环绕(间隔0.051是环绕触发, hit_cooldown0.3), 实际每火球0.3s可hit一次",
        "orbit_fire_count": 4, "hit_cooldown": 0.3,
    },
    "Riyan": {  # 赤曜
        "name": "赤曜", "interval": 1.0, "dmg_mul": 0.24,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "aura",
        "note": "光环每秒对所有范围内敌人: 24%ATK + 8%MAXHP",
        "hp_ratio": 0.08, "max_hp": 100,
    },
    # --- 范围/AoE类 (每发命中范围内全部) ---
    "Bloodwave": {  # 血气波
        "name": "血气波", "interval": 2.0, "dmg_mul": 1.0,
        "bullet": 1, "pen": 1, "pierce_decay": 0.0, "type": "line",
        "note": "波纹直线, 穿透1",
    },
    "BloodBoardSword": {  # 饮血刀
        "name": "饮血刀", "interval": 2.0, "dmg_mul": 0.80,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "aoe",
        "note": "范围挥砍命中范围内全部, 自带找最密集点",
        "aoe_factor": 1.0,
    },
    "Qiankun": {  # 乾坤双剑
        "name": "乾坤双剑", "interval": 3.5, "dmg_mul": 0.45,
        "bullet": 2, "pen": 1, "pierce_decay": 0.0, "type": "line",
        "note": "双剑各突进, 各穿透, hit_cooldown0.5",
    },
    "Xuanwu": {  # 玄武盾
        "name": "玄武盾", "interval": 4.0, "dmg_mul": 0.45,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "line",
        "note": "盾飞行穿透全命中, +7.5%MAXHP伤害",
        "hp_ratio": 0.075, "max_hp": 100,
    },
    "Genshan": {  # 艮山诀
        "name": "艮山诀", "interval": 3.5, "dmg_mul": 1.2,
        "bullet": 2, "pen": 999, "pierce_decay": 0.0, "type": "line",
        "note": "左右2向伸出墙, 全穿透",
    },
    "Duize": {  # 兑泽诀
        "name": "兑泽诀", "interval": 4.0, "dmg_mul": 0.24,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "dot",
        "note": "毒泽3.9s持续, 每0.5s一跳0.24倍, 找最密集点AoE",
        "duration": 3.9, "tick_interval": 0.5,
    },
    "HolyLight": {  # 圣光术
        "name": "圣光术", "interval": 3.2, "dmg_mul": 0.85,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "aoe",
        "note": "圣光范围命中全部, 自带找最密集点",
        "aoe_factor": 1.0,
    },
    "DragonWind": {  # 风龙杖
        "name": "风龙杖", "interval": 2.5, "dmg_mul": 0.9,
        "bullet": 1, "pen": 999, "pierce_decay": 0.0, "type": "aoe",
        "note": "龙卷范围持续命中, 自带找最密集点",
        "aoe_factor": 1.0,
    },
    "Qigong": {  # 气功波
        "name": "气功波", "interval": 1.2, "dmg_mul": 1.25,
        "bullet": 1, "pen": 1, "pierce_decay": 0.0, "type": "aoe",
        "note": "触碰爆炸, 溅射0.3倍, 主命中1+溅射周围",
        "splash": 0.3,
    },
}

# ============================================================
# 进阶项效果 (从各武器 .gd / player_action.gd build 函数提取)
# 格式: 每个进阶项对 DPS 维度的修改
# ============================================================
ADV = {
    # --- 剑气诀 ---
    "SplitSwordQi1": "+2侧弹(45°/315°), 每侧0.5倍, 每侧穿透同主弹",  # 单体+100%, 群怪+200%
    "SplitSwordQi2": "剑痕: 子弹留3s剑痕, 每0.5s 20%ATK (DPS+0.4/发)",
    "SplitSwordQi3": "穿云: 穿透+?",
    "SplitSwordQi4": "追踪: 命中率提升",
    # --- 仙枝 ---
    "Branch1": "半程分裂(分裂出3支, 每支继承伤害)",  # 弹数+3
    "Branch2": "渐强: 飞行伤害递增",
    "Branch3": "叶茂: 分裂数+",
    "Branch4": "枝繁: 范围+",
    "Branch11": "枝繁-叶茂",
    # --- 爆炎 ---
    "Moyan1": "每米伤害+6%/范围+4%",
    "Moyan3": "每3发一次巨大魔焰×1.8",
    "Moyan23": "每2发一次巨大魔焰×2.2 (强)",
    # --- 雷光/震雷 ---
    "Thunder1": "连锁+2(5次), 衰减55%",
    "Thunder11": "连锁+4(7次), 衰减45% (极强群怪)",
    "Thunder2": "射出2道(0.55倍)",
    "Thunder33": "射出3道(0.4倍)",
    # --- 天雷破 ---
    "ThunderBreak1": "伤害+10%, 宽度×1.3",
    "ThunderBreak2": "伤害+15%, 射程+120",
    "ThunderBreak11": "无限射程+10%伤害",
    # --- 光弹术 ---
    "LightBullet1": "穿透+2",
    "LightBullet5": "双发(×0.5)",
    "LightBullet11": "三发(×0.35)+蓄光上限+10",
    "LightBullet4": "每15发一圈额外弹",
    # --- 冰刺 ---
    "Ice1": "小冰+5, 散布+79°, 伤害-5%",
    "Ice3": "小冰+8, 伤害-5%",
    "Ice4": "穿透+1, 衰减70%",
    "Ice5": "伤害+10%",
    # --- 气功 ---
    "Qigong1": "伤害+10%, 必感电",
    "Qigong5": "脉轮(每其他武器+20%伤害)",
    # --- 赤曜 ---
    "Riyan2": "MAXHP伤害8%->15%",
    "Riyan22": "MAXHP伤害->16% (最强单体光环进阶)",
    # --- 离火 ---
    "RingFire1": "火球+1(5)",
    "RingFire2": "转速×1.25",
}

# ============================================================
# DPS 计算
# pc_atk = 1.0 (归一化), max_hp = 100
# ============================================================
PC_ATK = 1.0
MAX_HP = 100.0

def hits_on_enemies(weapon, n_enemies):
    """返回单次发射/单tick对 n 个敌人造成的总命中伤害倍率(×pc_atk)"""
    dmg = weapon["dmg_mul"]
    pen = weapon["pen"]
    decay = weapon.get("pierce_decay", 0.0)
    typ = weapon["type"]

    if typ == "aura":  # 赤曜/玄武: 每敌 dmg + hp_ratio*maxhp
        per_enemy = dmg + weapon.get("hp_ratio", 0.0) * MAX_HP
        return per_enemy * n_enemies

    if typ == "dot":  # 兑泽: 每tick对范围内全部
        return dmg * n_enemies

    if typ == "chain":  # 震雷连锁
        chain = min(weapon.get("chain", 1), n_enemies)
        total = 0.0
        cur = dmg
        for i in range(chain):
            total += cur
            cur *= (1.0 - weapon.get("chain_decay", 0.0))
        return total  # 连锁每跳打不同敌人

    if typ == "aoe":  # 范围命中全部
        return dmg * weapon.get("aoe_factor", 1.0) * n_enemies

    # line / orbit: 穿透模型
    bullet = weapon["bullet"]
    # 每发子弹能击中 min(pen, n) 个敌人, 衰减. pen=0 表示只命中1个(本身算1次)
    effective_pen = pen if pen > 0 else 1
    per_bullet = 0.0
    effective_targets = min(effective_pen, n_enemies)
    cur = dmg
    for i in range(effective_targets):
        per_bullet += cur
        cur *= (1.0 - decay)
    # 冰刺: 额外小冰刺
    if "small_count" in weapon:
        small_eff = min(weapon["small_count"], n_enemies)  # 小冰刺散布, 单体只中部分
        # 主冰刺集中, 小冰刺散布: 单体只算1主+部分小; 群怪小冰可命中更多
        per_bullet += dmg * weapon["small_ratio"] * small_eff
    return per_bullet * bullet

def compute_dps(weapon, n_enemies, with_adv=False, adv_set=None):
    """计算对 n_enemies 个敌人的DPS (×pc_atk)"""
    typ = weapon["type"]

    if typ == "dot":
        # 兑泽: 每 tick_interval 一次伤害, 持续 duration; 平均DPS
        tick_dmg = hits_on_enemies(weapon, n_enemies)
        ticks_per_sec = 1.0 / weapon["tick_interval"]
        return tick_dmg * ticks_per_sec

    if typ == "orbit":
        # 离火: orbit_fire_count 个火球, 每个每 hit_cooldown 秒可hit一次
        # 每秒每球命中次数 = 1/hit_cooldown (假设持续接触)
        per_hit = weapon["dmg_mul"]
        hits_per_sec_per_ball = 1.0 / weapon["hit_cooldown"]
        balls = weapon["orbit_fire_count"]
        # 每球命中 min(1,n) 个 (环绕球一般同时接触多敌, 简化:命中n个)
        return per_hit * hits_per_sec_per_ball * balls * min(n_enemies, balls)

    per_fire_total = hits_on_enemies(weapon, n_enemies)
    return per_fire_total / weapon["interval"]

# ============================================================
# 主分析
# ============================================================
def analyze():
    scenarios = [("单体 (1只)", 1), ("群怪 (3只)", 3), ("群怪 (10只)", 10)]

    results = {}
    for wkey, w in WEAPONS.items():
        results[wkey] = {}
        for label, n in scenarios:
            results[wkey][label] = compute_dps(w, n)

    # 输出表格
    print("=" * 90)
    print(f"{'武器':<12} {'间隔s':>6} {'倍率':>6} | {'单体DPS':>10} {'3只DPS':>10} {'10只DPS':>10} | {'群怪倍率(10/1)':>14}")
    print("=" * 90)
    # 按单体DPS排序
    for wkey in sorted(WEAPONS, key=lambda k: results[k]["单体 (1只)"], reverse=True):
        w = WEAPONS[wkey]
        d1 = results[wkey]["单体 (1只)"]
        d3 = results[wkey]["群怪 (3只)"]
        d10 = results[wkey]["群怪 (10只)"]
        ratio = d10 / d1 if d1 > 0 else 0
        print(f"{w['name']:<10} {w['interval']:>6.2f} {w['dmg_mul']:>6.2f} | {d1:>10.3f} {d3:>10.3f} {d10:>10.3f} | {ratio:>12.2f}x")

    # 统计
    print("\n" + "=" * 90)
    print("统计区间分析:")
    for label, n in scenarios:
        vals = [results[k][label] for k in WEAPONS]
        import statistics
        mean = statistics.mean(vals)
        stdev = statistics.stdev(vals)
        mx = max(vals)
        mn = min(vals)
        mxk = max(WEAPONS, key=lambda k: results[k][label])
        mnk = min(WEAPONS, key=lambda k: results[k][label])
        print(f"\n[{label}] 均值={mean:.3f} 标准差={stdev:.3f}")
        print(f"  最高: {WEAPONS[mxk]['name']} = {mx:.3f}")
        print(f"  最低: {WEAPONS[mnk]['name']} = {mn:.3f}")
        print(f"  最高/最低 = {mx/mn:.1f}x" if mn > 0 else f"  最高/最低 = ∞ (存在0DPS武器)")

    # 标记异常
    print("\n" + "=" * 90)
    print("异常武器识别 (偏离均值超过1个标准差):")
    for label, n in scenarios:
        vals = {k: results[k][label] for k in WEAPONS}
        mean = statistics.mean(vals.values())
        stdev = statistics.stdev(vals.values())
        print(f"\n[{label}] (均值={mean:.3f}, ±1σ=[{mean-stdev:.3f}, {mean+stdev:.3f}])")
        outliers = [(k, v) for k, v in vals.items() if v > mean + stdev or v < mean - stdev]
        for k, v in sorted(outliers, key=lambda x: x[1], reverse=True):
            direction = "偏高↑" if v > mean else "偏低↓"
            print(f"  {WEAPONS[k]['name']:<10} = {v:.3f}  ({direction}, 偏离{(v-mean)/stdev:+.2f}σ)")

    return results

if __name__ == "__main__":
    analyze()
