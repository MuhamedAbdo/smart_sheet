import re

with open('lib/screens/manual_job_order_dialog.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Constructor
code = re.sub(r'class ManualJobOrderDialog extends StatefulWidget \{.*?const ManualJobOrderDialog\(\{.*?\}\);', 
              'class ManualJobOrderDialog extends StatefulWidget {\n  const ManualJobOrderDialog({super.key});', 
              code, flags=re.DOTALL)

# 2. Add controllers
code = code.replace('final _generalNotesCtrl = TextEditingController();',
'''final _generalNotesCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final Map<int, TextEditingController> _itemNameCtrl = {};
  final Map<int, TextEditingController> _itemCodeCtrl = {};
  final Map<int, TextEditingController> _itemDimLCtrl = {};
  final Map<int, TextEditingController> _itemDimWCtrl = {};
  final Map<int, TextEditingController> _itemDimHCtrl = {};
  int _itemCounter = 0;''')

# 3. Modify initState & add _addItem
init_state_replacement = '''
  void _addItem() {
    if (_selectedIndices.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('«·Õœ «·√ﬁ’Ï 3 √’‰«›')));
      return;
    }
    setState(() {
      final idx = _itemCounter++;
      _selectedIndices.add(idx);
      _itemNameCtrl[idx] = TextEditingController();
      _itemCodeCtrl[idx] = TextEditingController();
      _itemDimLCtrl[idx] = TextEditingController();
      _itemDimWCtrl[idx] = TextEditingController();
      _itemDimHCtrl[idx] = TextEditingController();
      _qtyCtrl[idx] = TextEditingController();
      _itemNotesCtrl[idx] = TextEditingController();
      _itemSelectedCorrugations[idx] = [];
      _itemCustomCorrugationCtrl[idx] = TextEditingController();
      _itemSamplesCtrl[idx] = TextEditingController();
      _itemBoxSizeCtrl[idx] = TextEditingController();
      _itemSheetSizeCtrl[idx] = TextEditingController();
      _itemSheetCountCtrl[idx] = TextEditingController();
      _itemRollWidthCtrl[idx] = TextEditingController();
      _itemPaperLayerCtrls[idx] = [];
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dateStr = '//';
    _orderNumberCtrl.clear();
    _jobNumberCtrl.clear();
    _issueDateCtrl.text = dateStr;
    _clientCodeCtrl.text = '';
    _addItem();
  }
'''
code = re.sub(r'@override\s+void initState\(\)\s*\{.*?\}', init_state_replacement.strip(), code, flags=re.DOTALL)

# 4. Modify dispose to dispose new controllers
code = code.replace('_clientCodeCtrl.dispose();', '_clientCodeCtrl.dispose();\n    _clientNameCtrl.dispose();')

# 5. Modify _toggleItem (change it to remove item since they are all manually added)
toggle_replacement = '''
  void _toggleItem(int index) {
    if (_selectedIndices.length <= 1) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ÌÃ» ≈÷«›… ’‰› Ê«Õœ ⁄·Ï «·√ﬁ·')));
       return;
    }
    setState(() {
      _selectedIndices.remove(index);
    });
  }
'''
code = re.sub(r'void _toggleItem\(int index\) \{.*?\}\s*// ?? Layer Count Logic', toggle_replacement.strip() + '\n\n  // ?? Layer Count Logic', code, flags=re.DOTALL)

# 6. Modify _generate
gen_replacement = '''
    final items = _selectedIndices.map((idx) {
      return JobOrderItem(
        productName: _itemNameCtrl[idx]?.text ?? '',
        productCode: _itemCodeCtrl[idx]?.text ?? '',
        length: _itemDimLCtrl[idx]?.text ?? '',
        width: _itemDimWCtrl[idx]?.text ?? '',
        height: _itemDimHCtrl[idx]?.text ?? '',
        quantity: _qtyCtrl[idx]?.text ?? '',
        itemNotes: _itemNotesCtrl[idx]?.text ?? '',
        corrugationTypes: List.from(_itemSelectedCorrugations[idx] ?? []),
        customCorrugation: _itemCustomCorrugationCtrl[idx]?.text ?? '',
        corrugationSamples: _itemSamplesCtrl[idx]?.text ?? '',
        corrugationBoxSize: _itemBoxSizeCtrl[idx]?.text ?? '',
        corrugationSheetSize: _itemSheetSizeCtrl[idx]?.text ?? '',
        corrugationSheetCount: _itemSheetCountCtrl[idx]?.text ?? '',
        rollWidth: _itemRollWidthCtrl[idx]?.text ?? '',
        paperLayers: (_itemPaperLayerCtrls[idx] ?? []).map((c) => c.text).where((t) => t.isNotEmpty).toList(),
      );
    }).toList();
'''
code = re.sub(r'final items = _selectedIndices\.map\(\(idx\) \{.*?\n    \}\)\.toList\(\);', gen_replacement.strip(), code, flags=re.DOTALL)

code = code.replace('customerName: widget.clientName,', 'customerName: _clientNameCtrl.text,')
code = code.replace('address: widget.clientAddress,', "address: '',")
code = code.replace('supervisor: widget.clientSupervisor,', "supervisor: '',")
code = code.replace('phone: widget.clientPhone,', "phone: '',")
code = code.replace("Text('«·⁄„Ì·: '", "Text('≈œŒ«· ÌœÊÌ - ÿ·» Õ—'")

# 7. Add client name field to form panel
code = code.replace("_sectionTitle('»Ì«‰«  √„— «· ‘€Ì·', Icons.article_outlined, isDark),\n          const SizedBox(height: 12),",
"_sectionTitle('»Ì«‰«  √„— «· ‘€Ì·', Icons.article_outlined, isDark),\n          const SizedBox(height: 12),\n          _field('«”„ «·⁄„Ì·', _clientNameCtrl, isDark, hint: '√œŒ· «”„ «·⁄„Ì·'),\n          const SizedBox(height: 12),")

# 8. Modify _buildItemsPanel to render the list properly and add 'Add item' button
build_items_replacement = '''
  Widget _buildItemsPanel(bool isDark) {
    const accent = Color(0xFF1a3a6e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle(
                '«·√’‰«› ()',
                Icons.inventory_2_outlined,
                isDark,
              ),
              if (_selectedIndices.length < 3)
                InkWell(
                  onTap: _addItem,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text('≈÷«›… ’‰›', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: _selectedIndices.length,
            itemBuilder: (_, i) {
              final idx = _selectedIndices[i];
              final isSelected = true;
'''
code = re.sub(r'Widget _buildItemsPanel\(bool isDark\) \{.*?(?=return AnimatedContainer\()', build_items_replacement.lstrip(), code, flags=re.DOTALL)

# 9. Modify item card header to contain text fields for name, code, etc.
card_header_replacement = '''
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _toggleItem(idx),
                            child: Icon(Icons.delete_outline, color: Colors.red, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(flex: 2, child: _miniField('»Ì«‰ «·’‰› *', _itemNameCtrl[idx]!, isDark)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _miniField('«·ﬂÊœ', _itemCodeCtrl[idx]!, isDark)),
                                  ]
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _miniField('ÿÊ·', _itemDimLCtrl[idx]!, isDark)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _miniField('⁄—÷', _itemDimWCtrl[idx]!, isDark)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _miniField('«— ›«⁄', _itemDimHCtrl[idx]!, isDark)),
                                  ]
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
'''
code = re.sub(r'child: Padding\(\s*padding: const EdgeInsets.symmetric\(\s*horizontal: 12,\s*vertical: 10,\s*\),\s*child: Row\(\s*children: \[.*?\]\s*,\s*\)\s*,\s*\)\s*,\s*\)\s*,', card_header_replacement, code, flags=re.DOTALL)

with open('lib/screens/manual_job_order_dialog.dart', 'w', encoding='utf-8') as f:
    f.write(code)

