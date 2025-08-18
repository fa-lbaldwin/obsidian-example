---
aliases: ["Daily", "Today"]
tags:
  - daily-note
---

<%*
/* --- TEMPLATER: rename & move as YYYY-MM-DD into Journal/Daily/ --- */
const folderPath = "Journal/Daily/";
const fileName = tp.moment().format("YYYY-MM-DD");
const targetPath = `${folderPath}${fileName}.md`;
async function ensureFolder(path){
  const parts = path.split("/").filter(Boolean);
  let cur = "";
  for (const p of parts) {
    cur += p + "/";
    try { await app.vault.createFolder(cur); } catch(e){ /* exists */ }
  }
}
await ensureFolder(folderPath);
if (tp.file.path(false) !== targetPath) { await tp.file.move(targetPath); }
%>

<%*
/* --- PLUGIN CHECK: Dataview + Tasks --- */
const dataview_enabled = app.plugins.enabledPlugins.has("dataview");
const tasks_enabled = app.plugins.enabledPlugins.has("obsidian-tasks-plugin");
if (!dataview_enabled || !tasks_enabled) {
  new Notice("WARNING: Enable 'Dataview' and 'Tasks' for this template.", 15000);
}
%>

# 📅 <% tp.file.title %> - <% tp.moment().format("dddd") %>
> [!TIP] **Thought of the Day**
> *What's the one thing that, if accomplished, would make today a success?*

---

## 🚀 Daily Dashboard

### 🎯 Top 3 Priorities
1.  
2.  
3.  

### ✅ Systems & Status Check
- [ ] Review Monitoring Dashboards (`[[Link to Grafana]]`)
- [ ] Check CI/CD Pipeline Status (`[[Link to Jenkins/GitLab]]`)
- [ ] Triage new alerts in PagerDuty/Opsgenie
- [ ] Review overnight batch job failures
- [ ] Check for security vulnerabilities (`[[Link to Snyk/Dependabot]]`)

### 📝 Tasks

**🔥 Overdue**
```tasks
not done
due before <% tp.moment().format("YYYY-MM-DD") %>
path does not include Templates
