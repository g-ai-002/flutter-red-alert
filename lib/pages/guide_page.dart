import 'package:material_ui/material_ui.dart';

import '../game/battle_types.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          for (final (title, text) in _sections)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$title\n', style: _titleStyle),
                      TextSpan(text: text, style: _bodyStyle),
                    ],
                  ),
                ),
              ),
            ),
          const Text('提示：本作为纯单机游戏，进度与战绩保存在本地。', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

const TextStyle _titleStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 2.2);
const TextStyle _bodyStyle = TextStyle(fontSize: 12.5, height: 1.7);

final List<(String, String)> _sections = [
  (
    '战役目标',
    '• 遭遇战摧毁蓝军全部建筑即可获胜，赤军建筑被全灭则失败；蓝军会持续扩军并成波进攻。\n'
        '• 战役共五关：歼灭战开局，中段穿插斩首行动，最后一关直取指挥中心，通关后自动解锁下一关。',
  ),
  (
    '战争迷雾与雷达',
    '• 己方单位与建筑提供视野：未探索区域全黑，撤出视野后敌军会从画面与迷你地图上消失。\n'
        '• 指挥中心提供雷达，点击顶部雷达按钮可在 4 秒内标定全部敌军，冷却 45 秒。',
  ),
  (
    '经济与电力',
    '• 采矿车自动往返矿区与精炼厂，每次入库转化为资金；矿区采空后自动寻找最近矿脉。\n'
        '• 电厂供电、建筑耗电。电力不足时生产速度与防御塔射速减半，看到顶部电力变红就优先补电厂。',
  ),
  (
    '建造流程',
    '• 在下方建造栏选择建筑或单位，资金立即扣除并开始生产。\n'
        '• 建筑完成后卡片出现金色标记，点击进入放置模式；绿色表示可建，点击确认。\n'
        '• 建筑必须靠近己方已有建筑；水域、岩石与矿石上不能建造。\n'
        '• 指挥中心被摧毁后，只能用残存建筑重建。',
  ),
  (
    '兵种与克制',
    '${[for (final spec in unitSpecs.values) '• ${spec.name} · ¥${spec.cost}：${spec.kind.description}'].join('\n')}\n'
        '• 哨戒炮塔自动打地面，防空炮塔只打空中。\n'
        '• 工程兵自动维修车辆与建筑，自行火炮射程 11.5 格但 3 格内无法开火。',
  ),
  (
    '战略打击',
    '• 战车工厂建成后可建造导弹发射井（3000 资金，耗电 70），在线时持续蓄能，120 秒充满。\n'
        '• 蓄满后点击顶部「发射」，再点选地图目标呼叫东风快递：半径 4.2 格内的敌军受到递减伤害。\n'
        '• 东风快递只杀伤敌军，不会误伤己方；发射井被摧毁会清空蓄能。\n'
        '• 蓝军同样会建造发射井，并优先打击我方指挥中心。',
  ),
  (
    '操作方式',
    '• 点选己方单位，再点击地面移动；点击敌军或建筑发起攻击。\n'
        '• 拖动空白处平移视角，双指捏合缩放；左上角迷你地图可快速跳转。\n'
        '• 桌面端：左键框选、右键下达指令、滚轮缩放、WASD / 方向键平移。\n'
        '• 「全选」选中同型部队，「停止」取消指令，「定位」把视角移到选中目标。\n'
        '• 右上角可切换 1× / 2× 速度与暂停；Esc 取消放置、退出瞄准或打开暂停菜单。',
  ),
  (
    '开局建议',
    '• 先补电厂再建兵营，兵营完成后立刻造 2~3 名步兵防早期骚扰。\n'
        '• 尽快建造战车工厂，补充第 3 辆采矿车，经济领先才有装甲优势。\n'
        '• 蓝军第一波通常在数分钟内到达，提前在矿区与路口布置炮塔。\n'
        '• 中后期补一座发射井，用东风快递敲掉敌军炮塔群或指挥中心再推进。',
  ),
];
