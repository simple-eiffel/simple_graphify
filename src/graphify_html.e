note
	description: "[
		graph.html emitter: fully self-contained interactive visualization.
		Embeds the graph JSON and renders a deterministic community-clustered
		layout on a canvas with pan/zoom, hover tooltips, node detail panel,
		and search. No external network requests.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_HTML

create
	make

feature {NONE} -- Initialization

	make
			-- Create emitter.
		do
		end

feature -- Basic operations

	html_text (a_graph_json: STRING): STRING
			-- Complete graph.html embedding `a_graph_json`.
		require
			json_not_empty: not a_graph_json.is_empty
		do
			create Result.make (a_graph_json.count + Template_head.count + Template_tail.count + 64)
			Result.append (Template_head)
			Result.append (a_graph_json)
			Result.append (Template_tail)
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Template

	Template_head: STRING = "[
		<!DOCTYPE html>
		<html>
		<head>
		<meta charset="utf-8">
		<title>simple_graphify - knowledge graph</title>
		<style>
		body { margin:0; font-family:Segoe UI,Arial,sans-serif; background:#101418; color:#dde; overflow:hidden; }
		#c { display:block; cursor:grab; }
		#panel { position:fixed; top:0; right:0; width:320px; max-height:100vh; overflow-y:auto;
		  background:#1a2028ee; padding:12px 16px; font-size:13px; display:none; border-left:1px solid #345; }
		#panel h2 { margin:4px 0 8px; font-size:16px; }
		#panel .kind { color:#8ab; }
		#panel ul { padding-left:16px; margin:6px 0; }
		#search { position:fixed; top:10px; left:10px; width:260px; padding:6px 10px;
		  background:#1a2028; color:#dde; border:1px solid #456; border-radius:4px; font-size:13px; }
		#legend { position:fixed; bottom:10px; left:10px; font-size:12px; background:#1a2028cc;
		  padding:8px 12px; border-radius:4px; max-width:340px; }
		#tip { position:fixed; pointer-events:none; background:#000c; color:#fff; padding:4px 8px;
		  border-radius:3px; font-size:12px; display:none; z-index:5; }
		</style>
		</head>
		<body>
		<input id="search" placeholder="search nodes..." />
		<canvas id="c"></canvas>
		<div id="panel"></div>
		<div id="legend"></div>
		<div id="tip"></div>
		<script>
		const G =
	]"

	Template_tail: STRING = "[
		;
		const palette = ["#e6194b","#3cb44b","#ffe119","#4363d8","#f58231","#911eb4",
		  "#46f0f0","#f032e6","#bcf60c","#fabebe","#008080","#e6beff"];
		const canvas = document.getElementById("c");
		const ctx = canvas.getContext("2d");
		let W = 0, H = 0;
		function resize() { W = window.innerWidth; H = window.innerHeight; canvas.width = W; canvas.height = H; draw(); }
		window.addEventListener("resize", resize);

		const nodes = G.nodes, edges = G.edges;
		const byId = {};
		nodes.forEach(function (n) { byId[n.id] = n; });

		// Deterministic layout: communities on a ring, members on inner spirals.
		const comms = {};
		nodes.forEach(function (n) {
		  const c = n.community || 0;
		  if (!comms[c]) comms[c] = [];
		  comms[c].push(n);
		});
		const commIds = Object.keys(comms).sort(function (a, b) { return a - b; });
		const R = 340 + 24 * commIds.length;
		commIds.forEach(function (cid, k) {
		  const ang = (2 * Math.PI * k) / commIds.length;
		  const cx = commIds.length === 1 ? 0 : R * Math.cos(ang);
		  const cy = commIds.length === 1 ? 0 : R * Math.sin(ang);
		  const members = comms[cid];
		  members.sort(function (a, b) { return b.degree - a.degree || (a.id < b.id ? -1 : 1); });
		  members.forEach(function (n, i) {
		    const r = 14 * Math.sqrt(i);
		    const a2 = i * 2.39996; // golden angle spiral
		    n.x = cx + r * Math.cos(a2);
		    n.y = cy + r * Math.sin(a2);
		  });
		});

		let scale = 0.8, ox = 0, oy = 0, dragging = false, lx = 0, ly = 0;
		let highlight = null, selected = null, searchTerm = "";

		function nodeRadius(n) {
		  if (n.kind === "library") return 11;
		  if (n.kind === "class") return 4 + Math.min(8, Math.sqrt(n.degree));
		  if (n.kind === "cluster") return 7;
		  if (n.kind === "document") return 6;
		  if (n.kind === "feature") return 2.5;
		  return 3.5;
		}
		function nodeColor(n) {
		  const c = (n.community || 0) % palette.length;
		  return palette[c];
		}
		function toScreen(x, y) { return [W / 2 + (x + ox) * scale, H / 2 + (y + oy) * scale]; }

		function draw() {
		  ctx.clearRect(0, 0, W, H);
		  ctx.lineWidth = 0.5;
		  edges.forEach(function (e) {
		    const a = byId[e.from], b = byId[e.to];
		    if (!a || !b) return;
		    const dim = searchTerm && !(matches(a) || matches(b));
		    ctx.strokeStyle = dim ? "#2a3138" : (e.kind === "inherits" ? "#7a9cc6aa" :
		      e.kind === "contains" ? "#4a505888" : e.kind === "references" ? "#c6a97a88" : "#5a636e88");
		    const [x1, y1] = toScreen(a.x, a.y);
		    const [x2, y2] = toScreen(b.x, b.y);
		    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
		  });
		  nodes.forEach(function (n) {
		    const [x, y] = toScreen(n.x, n.y);
		    if (x < -20 || y < -20 || x > W + 20 || y > H + 20) return;
		    const r = nodeRadius(n) * Math.max(0.6, scale);
		    const dim = searchTerm && !matches(n);
		    ctx.fillStyle = dim ? "#333a42" : nodeColor(n);
		    ctx.beginPath();
		    if (n.kind === "document") { ctx.rect(x - r, y - r, 2 * r, 2 * r); }
		    else { ctx.arc(x, y, r, 0, 2 * Math.PI); }
		    ctx.fill();
		    if (n === selected || n === highlight) {
		      ctx.strokeStyle = "#fff"; ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 0.5;
		    }
		    if (scale > 1.6 || n.kind === "library" || (searchTerm && matches(n))) {
		      ctx.fillStyle = dim ? "#555" : "#cde";
		      ctx.font = "11px sans-serif";
		      ctx.fillText(n.label, x + r + 3, y + 3);
		    }
		  });
		}
		function matches(n) { return n.label.toLowerCase().indexOf(searchTerm) >= 0; }

		function nodeAt(mx, my) {
		  let best = null, bestD = 144;
		  nodes.forEach(function (n) {
		    const [x, y] = toScreen(n.x, n.y);
		    const d = (x - mx) * (x - mx) + (y - my) * (y - my);
		    if (d < bestD) { best = n; bestD = d; }
		  });
		  return best;
		}

		canvas.addEventListener("mousedown", function (e) { dragging = true; lx = e.clientX; ly = e.clientY; });
		window.addEventListener("mouseup", function () { dragging = false; });
		canvas.addEventListener("mousemove", function (e) {
		  if (dragging) {
		    ox += (e.clientX - lx) / scale; oy += (e.clientY - ly) / scale;
		    lx = e.clientX; ly = e.clientY; draw();
		  } else {
		    const n = nodeAt(e.clientX, e.clientY);
		    highlight = n;
		    const tip = document.getElementById("tip");
		    if (n) {
		      tip.style.display = "block";
		      tip.style.left = (e.clientX + 12) + "px";
		      tip.style.top = (e.clientY + 12) + "px";
		      tip.textContent = n.label + " (" + n.kind + ", degree " + n.degree + ")";
		    } else { tip.style.display = "none"; }
		    draw();
		  }
		});
		canvas.addEventListener("wheel", function (e) {
		  e.preventDefault();
		  scale *= e.deltaY < 0 ? 1.12 : 0.89;
		  scale = Math.max(0.05, Math.min(12, scale));
		  draw();
		});
		canvas.addEventListener("click", function (e) {
		  const n = nodeAt(e.clientX, e.clientY);
		  selected = n;
		  const panel = document.getElementById("panel");
		  if (!n) { panel.style.display = "none"; draw(); return; }
		  let html = "<h2>" + n.label + "</h2><div class='kind'>" + n.kind +
		    " - community " + n.community + " - degree " + n.degree + "</div>";
		  if (n.description) html += "<p>" + n.description + "</p>";
		  if (n.file) html += "<p>" + n.file + ":" + (n.line || "") + "</p>";
		  if (n.metrics) {
		    html += "<ul>";
		    Object.keys(n.metrics).sort().forEach(function (k) { html += "<li>" + k + ": " + n.metrics[k] + "</li>"; });
		    html += "</ul>";
		  }
		  const out = edges.filter(function (e2) { return e2.from === n.id; });
		  const inn = edges.filter(function (e2) { return e2.to === n.id; });
		  if (out.length) {
		    html += "<h3>Outgoing (" + out.length + ")</h3><ul>";
		    out.slice(0, 40).forEach(function (e2) { html += "<li>--" + e2.kind + "--&gt; " + e2.to + "</li>"; });
		    html += "</ul>";
		  }
		  if (inn.length) {
		    html += "<h3>Incoming (" + inn.length + ")</h3><ul>";
		    inn.slice(0, 40).forEach(function (e2) { html += "<li>" + e2.from + " --" + e2.kind + "--&gt;</li>"; });
		    html += "</ul>";
		  }
		  panel.innerHTML = html;
		  panel.style.display = "block";
		  draw();
		});
		document.getElementById("search").addEventListener("input", function (e) {
		  searchTerm = e.target.value.toLowerCase();
		  draw();
		});
		(function () {
		  const lg = document.getElementById("legend");
		  let html = "<b>" + (G.root || "graph") + "</b> - " + nodes.length + " nodes, " +
		    edges.length + " edges, " + (G.communities ? G.communities.length : 0) + " communities<br/>";
		  (G.communities || []).slice(0, 8).forEach(function (c) {
		    html += "<span style='color:" + palette[c.id % palette.length] + "'>&#9679;</span> " +
		      c.label + " (" + c.size + ") &nbsp;";
		  });
		  lg.innerHTML = html;
		})();
		resize();
		</script>
		</body>
		</html>
	]"

end
