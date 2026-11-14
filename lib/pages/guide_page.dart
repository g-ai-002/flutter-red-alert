import 'package:material_ui/material_ui.dart';

import '../game/battle_types.dart';
import '../theme/app_theme.dart';

/// 玩法说明：目标、经济、建造流程、兵种、战略打击与操作。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const _Section(Icons.flag, '战役目标', [
            _Text('遭遇战摧毁蓝军全部建筑即可获胜，赤军建筑被全灭则失败；蓝军会持续扩军并成波进攻。'),
            _Text('战役共五关：歼灭战开局，中段穿插斩首行动，最后一关直取指挥中心，通关后自动解锁下一关。'),
          ]),
          const _Section(Icons.radar, '战争迷雾与雷达', [
            _Text('己方单位与建筑提供视野：未探索区域全黑，撤出视野后敌军会从画面与迷你地图上消失。'),
            _Text('指挥中心提供雷达，点击顶部雷达按钮可在 4 秒内标定全部敌军，冷却 45 秒。'),
          ]),
          const _Section(Icons.paid, '经济与电力', [
            _Text('采矿车自动往返矿区与精炼厂，每次入库转化为资金；矿区采空后自动寻找最近矿脉。'),
            _Text('电厂供电、建筑耗电。电力不足时生产速度与防御塔射速减半，看到顶部电力变红就优先补电厂。'),
          ]),
          const _Section(Icons.construction, '建造流程', [
            _Text(
              '① 在下方建造栏选择建筑或单位，资金立即扣除并开始生产。'
              '② 建筑完成后卡片出现金色标记，点击进入放置模式。'
              '③ 绿色表示可建，点击确认，建筑必须靠近己方已有建筑。',
            ),
            _Text('水域、岩石与矿石上不能建造；指挥中心被摧毁后，只能用残存建筑重建。'),
          ]),
          _Section(Icons.groups, '兵种与克制', [
            for (final (kind, role) in _unitRoles)
              _Text('${unitSpecs[kind]!.name} · ¥${unitSpecs[kind]!.cost}：$role', bullet: true),
            const _Text('哨戒炮塔自动打地面，防空炮塔只打空中；工程兵自动维修，自行火炮射程 11.5 格但 3 格内无法开火。'),
          ]),
          const _Section(Icons.rocket_launch, '战略打击', [
            _Text('战车工厂建成后可建造导弹发射井（3000 资金，耗电 70）。发射井在线时持续蓄能，120 秒充满。'),
            _Text('蓄满后点击顶部「发射」，再点选地图目标即可呼叫东风快递：半径 4.2 格内的敌军受到递减伤害。'),
            _Text('东风快递只杀伤敌军，不会误伤己方；发射井被摧毁会清空蓄能，重建后需重新积累。'),
            _Text('蓝军同样会建造发射井，并优先用导弹打击我方指挥中心，看到「蓝军导弹」提示要尽快分散部队。'),
          ]),
          const _Section(Icons.touch_app, '操作方式', [
            _Text('点选己方单位，再点击地面移动；点击敌军或建筑发起攻击。'),
            _Text('拖动空白处平移视角，双指捏合缩放；左上角迷你地图可快速跳转。'),
            _Text('桌面端：左键框选、右键下达指令、滚轮缩放、WASD / 方向键平移。'),
            _Text('「全选」选中同型部队，「停止」取消指令，「定位」把视角移到选中目标。'),
            _Text('右上角可切换 1× / 2× 速度与暂停；Esc 取消放置、退出瞄准或打开暂停菜单。'),
          ]),
          const _Section(Icons.tips_and_updates, '开局建议', [
            _Text('先补电厂再建兵营，兵营完成后立刻造 2~3 名步兵防早期骚扰。'),
            _Text('尽快建造战车工厂，补充第 3 辆采矿车，经济领先才有装甲优势。'),
            _Text('蓝军第一波通常在数分钟内到达，提前在矿区与路口布置炮塔。'),
            _Text('中后期补一座发射井，用东风快递敲掉敌军炮塔群或指挥中心再推进。'),
          ]),
          const SizedBox(height: 12),
          const Text(
            '提示：本作为纯单机游戏，进度与战绩保存在本地。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: hudTextDim),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.icon, this.title, this.children);

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
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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

/// 说明文字：普通段落或带圆点的条目。
class _Text extends StatelessWidget {
  const _Text(this.text, {this.bullet = false});

  final String text;
  final bool bullet;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, height: 1.7);
    if (!bullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: style),
      );
    }
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
                decoration: BoxDecoration(color: appGold, shape: BoxShape.circle),
              ),
            ),
          ),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

const List<(UnitKind, String)> _unitRoles = [
  (UnitKind.rifle, '廉价主力，清理步兵效果好，对装甲伤害很低。'),
  (UnitKind.rocket, '反装甲核心，射程远，对坦克与建筑效果显著；可对空射击直升机。'),
  (UnitKind.engineer, '无武器，自动维修附近的车辆与建筑，需要部队护送。'),
  (UnitKind.harvester, '自动采矿，无武装。被袭击时尽快派兵驱赶敌军。'),
  (UnitKind.lightTank, '机动快，适合骚扰矿区与追击步兵。'),
  (UnitKind.heavyTank, '高血量高火力，攻坚与正面决战的主力。'),
  (UnitKind.artillery, '远程拆建筑与炮群，贴脸无法开火，靠队友掩护。'),
  (UnitKind.gunship, '无视地形直飞，机炮压制步兵；只会被防空炮塔与火箭兵击落。'),
];
