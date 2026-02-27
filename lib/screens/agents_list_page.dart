// File: agents_list_page.dart
// Neyvo – agents list: DataTable layout, status/industry/direction badges, empty state.

import 'package:flutter/material.dart';
import '../neyvo_pulse_api.dart';
import '../pulse_route_names.dart';
import '../theme/neyvo_theme.dart';
import '../widgets/neyvo_empty_state.dart';
import 'agent_creation_wizard.dart';

class AgentsListPage extends StatefulWidget {
  const AgentsListPage({super.key});

  @override
  State<AgentsListPage> createState() => _AgentsListPageState();
}

class _AgentsListPageState extends State<AgentsListPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _agents = [];
  String? _filterDirection;
  String? _filterIndustry;
  String? _selectedAgentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await NeyvoPulseApi.listAgents(
        direction: _filterDirection,
        industry: _filterIndustry,
        status: null,
      );
      if (res['ok'] == true && res['agents'] != null) {
        setState(() { _agents = List<dynamic>.from(res['agents'] as List); _loading = false; });
      } else {
        setState(() { _error = res['error'] as String? ?? 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openCreateAgent() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => const AgentCreationWizard(),
    );
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1200;
    return Scaffold(
      backgroundColor: NeyvoColors.bgVoid,
      body: isWide ? _wideBody() : _body(),
    );
  }

  Widget _body() {
    if (_loading) return buildNeyvoLoadingState();
    if (_error != null) return buildNeyvoErrorState(onRetry: _load);
    if (_agents.isEmpty) return _emptyState();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Agents', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, PulseRouteNames.students),
                    icon: const Icon(Icons.people_outlined, size: 18),
                    label: const Text('Contacts'),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _openCreateAgent,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ New Agent'),
                style: FilledButton.styleFrom(
                  backgroundColor: NeyvoColors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          NeyvoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tableHeader(),
                ...List.generate(_agents.length, (i) => _agentRow(i, _agents[i] as Map<String, dynamic>)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideBody() {
    if (_loading) return buildNeyvoLoadingState();
    if (_error != null) return buildNeyvoErrorState(onRetry: _load);
    if (_agents.isEmpty) return _emptyState();

    final currentSelected = _selectedAgentId;
    if (currentSelected == null && _agents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedAgentId == null && _agents.isNotEmpty) {
          setState(() {
            _selectedAgentId = (_agents.first as Map<String, dynamic>)['id'] as String?;
          });
        }
      });
    }

    return Row(
      children: [
        Expanded(
          flex: 6,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Agents', style: NeyvoTextStyles.title.copyWith(color: NeyvoColors.textPrimary)),
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(context, PulseRouteNames.students),
                          icon: const Icon(Icons.people_outlined, size: 18),
                          label: const Text('Contacts'),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _openCreateAgent,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('+ New Agent'),
                      style: FilledButton.styleFrom(
                        backgroundColor: NeyvoColors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                NeyvoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _tableHeader(),
                      ...List.generate(_agents.length, (i) => _agentRow(i, _agents[i] as Map<String, dynamic>)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: NeyvoColors.borderSubtle),
        Expanded(
          flex: 7,
          child: _selectedAgentId == null
              ? Center(
                  child: Text(
                    'Select an agent to see details.',
                    style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textSecondary),
                  ),
                )
              : AgentDetailPage(agentId: _selectedAgentId!),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: NeyvoColors.textMuted),
            const SizedBox(height: 16),
            Text('No agents yet', style: NeyvoTextStyles.heading.copyWith(color: NeyvoColors.textSecondary)),
            const SizedBox(height: 8),
            SizedBox(
              width: 300,
              child: Text(
                'Create your first AI agent to start handling calls.',
                style: NeyvoTextStyles.body.copyWith(color: NeyvoColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _openCreateAgent,
              style: FilledButton.styleFrom(
                backgroundColor: NeyvoColors.teal,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
              child: const Text('+ Create Agent'),
            ),
            const SizedBox(height: 12),
            Text(
              'Takes about 30 seconds to set up',
              style: NeyvoTextStyles.micro.copyWith(color: NeyvoColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: NeyvoColors.textMuted,
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('STATUS', style: style)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: Text('AGENT NAME', style: style)),
          SizedBox(width: 90, child: Text('INDUSTRY', style: style)),
          SizedBox(width: 90, child: Text('DIRECTION', style: style)),
          SizedBox(width: 80, child: Text('VOICE', style: style)),
          SizedBox(width: 90, child: Text('LAST CALL', style: style)),
          SizedBox(width: 56, child: Text('CALLS', style: style)),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _agentRow(int index, Map<String, dynamic> a) {
    final name = a['name'] as String? ?? 'Unnamed';
    final direction = (a['direction'] as String?)?.toLowerCase() ?? '';
    final industry = (a['industry'] as String?) ?? '';
    final status = (a['status'] as String?)?.toLowerCase() ?? 'active';
    final voiceTier = (a['voice_tier'] as String?) ?? 'neutral';
    final lastCall = a['last_call_at'];
    final callsCount = a['calls_count'] as num? ?? 0;
    final id = a['id'] as String?;

    Color statusColor = NeyvoColors.textMuted;
    if (status == 'active') statusColor = NeyvoColors.success;
    if (status == 'draft') statusColor = NeyvoColors.warning;

    String lastCallStr = '—';
    if (lastCall != null) {
      final dt = lastCall is DateTime ? lastCall : DateTime.tryParse(lastCall.toString());
      if (dt != null) {
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) lastCallStr = '${diff.inMinutes}m ago';
        else if (diff.inHours < 24) lastCallStr = '${diff.inHours}h ago';
        else lastCallStr = '${diff.inDays}d ago';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id != null
            ? () {
                final width = MediaQuery.of(context).size.width;
                final isWide = width >= 1200;
                if (isWide) {
                  setState(() {
                    _selectedAgentId = id;
                  });
                } else {
                  Navigator.pushNamed(
                    context,
                    PulseRouteNames.agentDetail,
                    arguments: id,
                  );
                }
              }
            : null,
        hoverColor: NeyvoColors.bgHover,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: NeyvoColors.borderSubtle)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: status == 'active' ? [BoxShadow(color: NeyvoColors.success.withValues(alpha: 0.6), blurRadius: 6)] : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(name, style: NeyvoTextStyles.bodyPrimary.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 90,
                child: _industryBadge(industry),
              ),
              SizedBox(
                width: 90,
                child: _directionBadge(direction),
              ),
              SizedBox(
                width: 80,
                child: Text(voiceTier, style: NeyvoTextStyles.micro, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 90,
                child: Text(lastCallStr, style: NeyvoTextStyles.micro, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 56,
                child: Text('$callsCount', style: NeyvoTextStyles.label.copyWith(color: NeyvoColors.textSecondary)),
              ),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: id != null ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentDetailPage(agentId: id))) : null, color: NeyvoColors.textSecondary, style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero)),
                    IconButton(icon: const Icon(Icons.phone_outlined, size: 18), onPressed: () {}, color: NeyvoColors.textSecondary, style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero)),
                    IconButton(icon: const Icon(Icons.more_vert, size: 18), onPressed: () {}, color: NeyvoColors.textSecondary, style: IconButton.styleFrom(minimumSize: const Size(36, 36), padding: EdgeInsets.zero)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _industryBadge(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: NeyvoColors.borderDefault.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: NeyvoColors.borderDefault),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: NeyvoTextStyles.micro.copyWith(fontSize: 11, color: NeyvoColors.textPrimary, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _directionBadge(String dir) {
    Color bg = NeyvoColors.info.withValues(alpha: 0.1);
    Color fg = NeyvoColors.info;
    String label = 'Inbound';
    if (dir == 'outbound') {
      bg = NeyvoColors.teal.withValues(alpha: 0.1);
      fg = NeyvoColors.teal;
      label = 'Outbound';
    } else if (dir == 'hybrid') {
      bg = NeyvoColors.coral.withValues(alpha: 0.1);
      fg = NeyvoColors.coral;
      label = 'Hybrid';
    }
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(label, style: NeyvoTextStyles.micro.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
