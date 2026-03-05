#!/usr/bin/env node

/**
 * スキルのSKILL.mdからgraphviz図をSVGファイルにレンダリングする。
 *
 * 使い方:
 *   ./render-graphs.js <skill-directory>           # 各図を個別にレンダリング
 *   ./render-graphs.js <skill-directory> --combine # すべての図を1つにまとめる
 *
 * SKILL.md内のすべての```dotブロックを抽出してSVGにレンダリングする。
 * あなたの人間パートナーがプロセスフローを視覚化するのに役立つ。
 *
 * 必須: graphviz (dot) がシステムにインストールされていること
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function extractDotBlocks(markdown) {
  const blocks = [];
  const regex = /```dot\n([\s\S]*?)```/g;
  let match;

  while ((match = regex.exec(markdown)) !== null) {
    const content = match[1].trim();

    // digraph名を抽出
    const nameMatch = content.match(/digraph\s+(\w+)/);
    const name = nameMatch ? nameMatch[1] : `graph_${blocks.length + 1}`;

    blocks.push({ name, content });
  }

  return blocks;
}

function extractGraphBody(dotContent) {
  // digraphから本体（ノードとエッジ）のみを抽出
  const match = dotContent.match(/digraph\s+\w+\s*\{([\s\S]*)\}/);
  if (!match) return "";

  let body = match[1];

  // rankdirを削除（トップレベルで一度だけ設定するため）
  body = body.replace(/^\s*rankdir\s*=\s*\w+\s*;?\s*$/gm, "");

  return body.trim();
}

function combineGraphs(blocks, skillName) {
  const bodies = blocks.map((block, i) => {
    const body = extractGraphBody(block.content);
    // 視覚的なグループ化のために各サブグラフをクラスターでラップ
    return `  subgraph cluster_${i} {
    label="${block.name}";
    ${body
      .split("\n")
      .map((line) => "  " + line)
      .join("\n")}
  }`;
  });

  return `digraph ${skillName}_combined {
  rankdir=TB;
  compound=true;
  newrank=true;

${bodies.join("\n\n")}
}`;
}

function renderToSvg(dotContent) {
  try {
    return execSync("dot -Tsvg", {
      input: dotContent,
      encoding: "utf-8",
      maxBuffer: 10 * 1024 * 1024,
    });
  } catch (err) {
    console.error("dotの実行エラー:", err.message);
    if (err.stderr) console.error(err.stderr.toString());
    return null;
  }
}

function main() {
  const args = process.argv.slice(2);
  const combine = args.includes("--combine");
  const skillDirArg = args.find((a) => !a.startsWith("--"));

  if (!skillDirArg) {
    console.error("使い方: render-graphs.js <skill-directory> [--combine]");
    console.error("");
    console.error("オプション:");
    console.error("  --combine    すべての図を1つのSVGにまとめる");
    console.error("");
    console.error("例:");
    console.error("  ./render-graphs.js ../subagent-driven-development");
    console.error("  ./render-graphs.js ../subagent-driven-development --combine");
    process.exit(1);
  }

  const skillDir = path.resolve(skillDirArg);
  const skillFile = path.join(skillDir, "SKILL.md");
  const skillName = path.basename(skillDir).replace(/-/g, "_");

  if (!fs.existsSync(skillFile)) {
    console.error(`エラー: ${skillFile} が見つかりません`);
    process.exit(1);
  }

  // dotが利用可能か確認
  try {
    execSync("which dot", { encoding: "utf-8" });
  } catch {
    console.error("エラー: graphviz (dot) が見つかりません。以下でインストールしてください:");
    console.error("  brew install graphviz    # macOS");
    console.error("  apt install graphviz     # Linux");
    process.exit(1);
  }

  const markdown = fs.readFileSync(skillFile, "utf-8");
  const blocks = extractDotBlocks(markdown);

  if (blocks.length === 0) {
    console.log("```dotブロックが見つかりません:", skillFile);
    process.exit(0);
  }

  console.log(`${blocks.length}個の図が見つかりました: ${path.basename(skillDir)}/SKILL.md`);

  const outputDir = path.join(skillDir, "diagrams");
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir);
  }

  if (combine) {
    // すべてのグラフを1つにまとめる
    const combined = combineGraphs(blocks, skillName);
    const svg = renderToSvg(combined);
    if (svg) {
      const outputPath = path.join(outputDir, `${skillName}_combined.svg`);
      fs.writeFileSync(outputPath, svg);
      console.log(`  レンダリング完了: ${skillName}_combined.svg`);

      // デバッグ用にdotソースも書き出す
      const dotPath = path.join(outputDir, `${skillName}_combined.dot`);
      fs.writeFileSync(dotPath, combined);
      console.log(`  ソース: ${skillName}_combined.dot`);
    } else {
      console.error("  結合図のレンダリングに失敗しました");
    }
  } else {
    // 各図を個別にレンダリング
    for (const block of blocks) {
      const svg = renderToSvg(block.content);
      if (svg) {
        const outputPath = path.join(outputDir, `${block.name}.svg`);
        fs.writeFileSync(outputPath, svg);
        console.log(`  レンダリング完了: ${block.name}.svg`);
      } else {
        console.error(`  失敗: ${block.name}`);
      }
    }
  }

  console.log(`\n出力先: ${outputDir}/`);
}

main();
