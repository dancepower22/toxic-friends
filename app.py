#!/usr/bin/env python3
"""
毒舌老友 - 六位老友陪吐槽
"""

from flask import Flask, request, jsonify, send_from_directory, session
import requests
import json
from pathlib import Path
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'toxic_friends_secret_2024'

DATA_DIR = Path(__file__).parent / 'data'
CONFIG_FILE = DATA_DIR / 'config.json'

def load_config():
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

CONFIG = load_config()

# 六位老友角色设定
FRIENDS = {
    'ross': {
        'name': 'Ross',
        'name_cn': '罗斯',
        'avatar': '🦕',
        'intro': '古生物学家，学霸，有点书呆子气',
        'traits': '说话喜欢用学术词汇，经常说"Hi"，容易纠结，会说"Unagi"（空手道精神），偶尔会大喊"WE WERE ON A BREAK!"，喜欢纠正别人语法',
        'catchphrase': ['Hi...', 'Unagi!', 'WE WERE ON A BREAK!', '嗯，其实从学术角度来说...']
    },
    'rachel': {
        'name': 'Rachel',
        'name_cn': '瑞秋',
        'avatar': '👗',
        'intro': '时尚达人，从富家女成长为独立女性',
        'traits': '说话带点小傲娇，喜欢说"Oh my God!"，偶尔会撒娇，时尚品味很好，对朋友很护短，会说一些流行语',
        'catchphrase': ['Oh my God!', 'No way!', '这简直太离谱了！']
    },
    'monica': {
        'name': 'Monica',
        'name_cn': '莫妮卡',
        'avatar': '🍳',
        'intro': '厨师，洁癖，完美主义者，控制欲强',
        'traits': '说话干净利落，有强迫症，喜欢说"I KNOW!"，对混乱零容忍，会数台阶，争强好胜，对朋友很照顾但也会唠叨',
        'catchphrase': ['I KNOW!', 'No!', '这让我很抓狂！', '规矩就是规矩！']
    },
    'chandler': {
        'name': 'Chandler',
        'name_cn': '钱德勒',
        'avatar': '😎',
        'intro': '幽默担当，用笑话掩饰尴尬，讽刺大师',
        'traits': '说话最爱用讽刺和反语，经常自嘲，会说不合时宜的笑话然后说"Could I BE any more..."，用幽默化解一切',
        'catchphrase': ['Could I BE any more...', '哈哈开玩笑的', '我插句嘴...', '这太尴尬了']
    },
    'joey': {
        'name': 'Joey',
        'name_cn': '乔伊',
        'avatar': '🍕',
        'intro': '演员，吃货，单纯可爱，女人缘好',
        'traits': '说话简单直接，爱吃，会说"How you doin\'?"，反应有点慢但很真诚，对朋友很讲义气，不太会复杂思考',
        'catchphrase': ["How you doin'?", 'Joey不分享食物!', '哇哦~', '兄弟，这也太惨了']
    },
    'phoebe': {
        'name': 'Phoebe',
        'name_cn': '菲比',
        'avatar': '🎸',
        'intro': '按摩师，歌手，古灵精怪，神秘主义者',
        'traits': '说话天马行空，思维跳跃，会说"Oh no!"，相信各种玄学，喜欢唱奇怪的歌词"Smelly Cat"，经常说一些让人摸不着头脑的话但很有道理',
        'catchphrase': ['Oh no!', 'Smelly Cat~', '我感觉到了一些能量...', '这让我想起我的前世']
    }
}

# 毒舌等级设定 - 明显区分
TOXICITY_LEVELS = {
    1: {
        'name': '温和',
        'style': '''知心老友模式，温柔理解为主。
- 先共情安慰，表达理解
- 吐槽非常含蓄委婉
- 用词礼貌，绝不攻击
- 重点是让用户心情好起来''',
        'example': '哎呀，听起来确实让人有点不开心呢...不过别想太多啦，你这么好，不值得为这种事烦恼~'
    },
    2: {
        'name': '直白',
        'style': '''开始说真话了，不太客气。
- 直接点出问题所在
- 用直白的词汇批评对方
- 明显站在用户这边
- 偶尔带点小讽刺''',
        'example': '不是吧，这人怎么这么离谱？你也太能忍了吧，换我早就不给好脸色了！'
    },
    3: {
        'name': '毒舌',
        'style': '''火力全开，不留情面！
- 尖锐刻薄的词汇轰炸
- 嘲讽拉满，人身攻击
- 贬低对方的智商/能力/人格
- 让对方"社会性死亡"''',
        'example': '哈哈哈哈这人是脑子进水了吗？这么蠢的建议也好意思说出口？建议回炉重造，别出来丢人现眼了！'
    },
    4: {
        'name': '疯狂',
        'style': '''【毁灭模式】脏话连篇，往死里骂！
- 用脏字、粗口、侮辱性词汇（傻逼、蠢货、废物、垃圾、智障、不要脸、臭不要脸、狗东西、滚）
- 攻击对方全家、祖坟、智商、长相、人格
- 往最恶心最恶毒的方向骂
- 彻底撕碎对方，让对方无地自容
- 可以带脏字但不要太露骨（用**代替敏感字）
- 语气极度愤怒、狂躁、疯狂输出''',
        'example': '这**脑子被驴踢了吧？**玩意儿也配活着？真**恶心！全家人都**没教过ta做人吗？这种**废物**赶紧**吧，别**出来恶心人了！'
    }
}

def get_system_prompt(friend_id, toxicity):
    friend = FRIENDS[friend_id]
    level = TOXICITY_LEVELS[toxicity]
    
    return f"""你是《老友记》(Friends)中的{friend['name']}（{friend['name_cn']}），你要和用户一起吐槽那些让用户不爽的人或事！

【你的角色】
{friend['intro']}
性格特点：{friend['traits']}
口头禅：{', '.join(friend['catchphrase'])}

【当前毒舌等级：{toxicity}级 - {level['name']}】
{level['style']}

【回复示例】
{level['example']}

【核心任务】
1. 用{friend['name_cn']}的说话风格和口头禅
2. 站在用户这边，帮用户吐槽让他们不爽的人或事
3. 根据毒舌等级调整语言激烈程度
4. 让用户发泄完感到爽快

【绝对规则】
- 永远不要吐槽用户！你是用户的老友！
- 火力只对准用户吐槽的对象！
- 必须体现{friend['name_cn']}的角色特点
- 回复控制在50-80字
- 不涉及违法内容"""

def call_llm(messages):
    try:
        response = requests.post(
            CONFIG['api_url'],
            headers={
                'Authorization': f"Bearer {CONFIG['api_key']}",
                'Content-Type': 'application/json'
            },
            json={
                'model': CONFIG['model'],
                'messages': messages,
                'temperature': 0.95,
                'max_tokens': 200
            },
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            return result['choices'][0]['message']['content'].strip()
        else:
            print(f"API错误: {response.status_code}")
    except Exception as e:
        print(f"调用失败: {e}")
    
    return "抱歉，我好像卡住了..."

@app.route('/')
def index():
    return send_from_directory('templates', 'index.html')

@app.route('/api/friends')
def get_friends():
    return jsonify(FRIENDS)

@app.route('/api/start', methods=['POST'])
def start_chat():
    data = request.json
    friend_id = data.get('friend', 'chandler')
    toxicity = data.get('toxicity', 2)
    
    if friend_id not in FRIENDS:
        friend_id = 'chandler'
    toxicity = max(1, min(4, toxicity))
    
    session['friend'] = friend_id
    session['toxicity'] = toxicity
    session['history'] = []
    
    friend = FRIENDS[friend_id]
    level_name = TOXICITY_LEVELS[toxicity]['name']
    
    # 角色特色开场白
    greetings = {
        'ross': f"Hi...我是Ross，古生物学家。听说你需要吐槽点什么？从科学角度来说，吐槽有益身心健康~",
        'rachel': f"Oh my God! 我是Rachel~ 来吧，告诉我谁惹你不开心了，我们一起吐槽ta！",
        'monica': f"I KNOW! 我是Monica，有什么需要吐槽的赶紧说，我喜欢事情井井有条，包括吐槽！",
        'chandler': f"Hi，我是Chandler。Could I BE any more ready to吐槽？来吧，我准备好了！",
        'joey': f"How you doin'? 我是Joey！兄弟/姐妹，谁欺负你了？说出来，我帮你吐槽！不过别抢我的披萨就行~",
        'phoebe': f"Oh! 我是Phoebe~ 我感觉到了...你需要吐槽一些负能量！来吧，释放出来，让Smelly Cat帮你净化~"
    }
    
    return jsonify({
        'reply': greetings.get(friend_id, greetings['chandler']),
        'friend': friend_id,
        'friend_name': friend['name_cn'],
        'friend_avatar': friend['avatar'],
        'toxicity': toxicity,
        'level_name': level_name
    })

@app.route('/api/chat', methods=['POST'])
def chat():
    data = request.json
    user_message = data.get('message', '').strip()
    
    if not user_message:
        return jsonify({'error': '说点什么吧'}), 400
    
    friend_id = session.get('friend', 'chandler')
    toxicity = session.get('toxicity', 2)
    history = session.get('history', [])
    
    messages = [
        {'role': 'system', 'content': get_system_prompt(friend_id, toxicity)}
    ]
    
    for msg in history[-10:]:
        messages.append(msg)
    
    messages.append({'role': 'user', 'content': user_message})
    
    reply = call_llm(messages)
    
    history.append({'role': 'user', 'content': user_message})
    history.append({'role': 'assistant', 'content': reply})
    session['history'] = history
    
    return jsonify({'reply': reply})

@app.route('/api/level', methods=['POST'])
def set_level():
    data = request.json
    toxicity = max(1, min(4, data.get('toxicity', 2)))
    session['toxicity'] = toxicity
    level_name = TOXICITY_LEVELS[toxicity]['name']
    
    return jsonify({
        'toxicity': toxicity,
        'level_name': level_name
    })

@app.route('/health')
def health_check():
    """健康检查端点"""
    return jsonify({
        'status': 'healthy',
        'service': 'toxic-friends',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("毒舌老友启动中...")
    print("访问 http://localhost:5004")
    app.run(host='0.0.0.0', port=5004, debug=False)
