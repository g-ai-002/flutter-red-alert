import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 玩法说明：目标、经济、建造流程、兵种与操作。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: const [
          _Section(
            icon: Icons.flag,
            title: '战役目标',
            children: [
              _Paragraph(
                '摧毁蓝军的全部建筑即可获胜；赤军建筑被全部摧毁则失败。'
                '蓝军会不断扩军并成波进攻，稳住经济、及时补防线是关键。',
              ),
            ],
          ),
          _Section(
            icon: Icons.paid,
            title: '经济与电力',
            children: [
              _Paragraph(
                '采矿车会自动往返矿区与矿石精炼厂，每次入库都会转化为资金。'
                '开局有两辆采矿车，矿区采空后会自动寻找最近的矿脉。',
              ),
              _Paragraph(
                '电厂提供电力，建筑会消耗电力。电力不足时生产速度与防御塔射速减半，'
                '看到顶部电力变红就优先补电厂。',
              ),
            ],
          ),
          _Section(
            icon: Icons.construction,
            title: '建造流程',
            children: [
              _Paragraph(
                '① 在下方建造栏选择建筑或单位，资金会立即扣除并开始生产。'
                '② 建筑完成后卡片出现金色标记，点击后进入放置模式。'
                '③ 移动光标或手指选择位置，绿色表示可以建造，点击确认。',
              ),
              _Paragraph(
                '建筑必须靠近己方已有建筑（指挥中心 9 格，其他建筑 7 格）；'
                '水域、岩石与矿石上不能建造。',
              ),
            ],
          ),
          _Section(
            icon: Icons.groups,
            title: '兵种与克制',
            children: [
              _UnitRow(
                name: '步兵',
                role: '廉价主力，清理步兵效果好，对装甲伤害很低。',
                cost: '200',
              ),
              _UnitRow(
                name: '火箭兵',
                role: '反装甲核心，射程远，对坦克与建筑效果显著。',
                cost: '350',
              ),
              _UnitRow(
                name: '采矿车',
                role: '自动采矿，无武装。被袭击时尽快派兵驱赶敌军。',
                cost: '1000',
              ),
              _UnitRow(
                name: '轻型坦克',
                role: '机动快，适合骚扰矿区与追击步兵。',
                cost: '700',
              ),
              _UnitRow(
                name: '重型坦克',
                role: '高血量高火力，攻坚与正面决战的主力。',
                cost: '1500',
              ),
              _Paragraph(
                '哨戒炮塔自动攻击射程内目标，适合放在矿区与基地入口；'
                '但它耗电，电力不足时射速会下降。',
              ),
            ],
          ),
          _Section(
            icon: Icons.touch_app,
            title: '操作方式',
            children: [
              _Bullet('点选己方单位，再点击地面移动；点击敌军或建筑发起攻击。'),
              _Bullet('拖动空白处平移视角，双指捏合缩放；左上角迷你地图可快速跳转。'),
              _Bullet('桌面端：左键框选、右键下达指令、滚轮缩放、WASD / 方向键平移。'),
              _Bullet('「全选」选中同型部队，「停止」取消当前指令，「定位」把视角移到选中目标。'),
              _Bullet('右上角可以切换 1× / 2× 速度与暂停；Esc 取消放置或打开暂停菜单。'),
            ],
          ),
          _Section(
            icon: Icons.tips_and_updates,
            title: '开局建议',
            children: [
              _Bullet('先补一座电厂，再建兵营；兵营完成后立刻造 2~3 名步兵防早期骚扰。'),
              _Bullet('尽快建造战车工厂，补充第 3 辆采矿车，经济领先才有装甲优势。'),
              _Bullet('蓝军第一波通常在数分钟内到达，提前在矿区与路口布置炮塔。'),
              _Bullet('攒够 4~6 辆坦克再推进，沿公路走能提高移动速度。'),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '提示：本作为纯单机游戏，进度与战绩保存在本地。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF8B8172)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: appRed),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, height: 1.75),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 6),
            child: SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: appGold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.name,
    required this.role,
    required this.cost,
  });

  final String name;
  final String role;
  final String cost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: appRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              name,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              role,
              style: const TextStyle(fontSize: 12, height: 1.6),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '¥$cost',
            style: const TextStyle(fontSize: 11, color: Color(0xFF8B8172)),
          ),
        ],
      ),
    );
  }
}
