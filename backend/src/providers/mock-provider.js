export async function createMockReply({ message }) {
  return [
    '现在使用的是本地 mock provider，所以这条回复还不是真实模型生成的。',
    `我已经收到你的消息：“${message}”。`,
    '这说明当前已经跑通了 Flutter -> Node backend 这一段链路。',
    '下一步只要补上方舟配置，我们就可以把这里切成真实的豆包回复。',
  ].join('\n');
}

export async function createMockArtworkCritique({
  displayImageUrl,
  studentName,
  studentNote,
  title,
}) {
  const titleText = title || '这张作品';
  const studentLabel = studentName || '这位同学';
  const noteHint = studentNote
      ? `学生补充说明是：${studentNote}。`
      : '当前还没有学生补充说明。'
    ;

  return {
    summary:
      `${studentLabel}提交了《${titleText}》的分析请求。当前是 mock 模式，` +
      '所以这份结果还不是基于真实图像识别，而是给你看最终数据结构会长什么样。',
    scores: {
      composition: 74,
      shape: 69,
      color: 72,
      light: 67,
    },
    strengths: ['主体比较明确', '画面情绪已经出现', '有基本的色块组织意识'],
    weaknesses: ['明暗转折不够清晰', '边缘控制略松散', '背景和主体层次还不够拉开'],
    revisionSuggestions: [
      '先只用黑白灰重新概括一次大关系，确认主体受光面与背光面的边界。',
      '把最重要的轮廓边做实，次要边缘适当虚化，提升视觉焦点。',
      '减少杂色，把主色调统一后再局部加强点睛色。',
    ],
    nextExercise: '用同一张作品做 15 分钟黑白灰重画练习，再重新上色对比。',
    tags: ['人物速写', '色彩练习', '层次提升'],
    referencePrompt:
      `基于原图 ${displayImageUrl || '当前作品'}，生成一张更成熟的教学参考图。` +
      '要求保留原作品主体和主题，不改变核心构图；' +
      '强化黑白灰大关系、明确光源方向、提升背景与主体层次、统一整体色调。' +
      noteHint,
  };
}

export async function createMockReferenceImage({ artwork }) {
  return {
    imageUrl: artwork.imageUrl,
    note:
      '当前仍是 mock 模式，所以这里先返回原图地址，方便把“会员生成参考图”的完整产品链路走通。',
  };
}
