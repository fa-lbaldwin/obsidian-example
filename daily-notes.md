---
aliases: ["Daily", "Today"]
tags:
  - daily-note
  - "<% tp.moment().format('YYYY') %>"
  - "<% tp.moment().format('YYYY-MM') %>"
date: <% tp.moment().format("YYYY-MM-DD") %>
weekday: <% tp.moment().format("dddd") %>
week: <% tp.moment().format("YYYY-[W]WW") %>
---

<%*
/* --- TEMPLATER: rename & move as YYYY-MM-DD into Journal/Daily/ --- */
const folderPath = "Journal/Daily/";
const fileName = tp.moment().format("YYYY-MM-DD");
const targetPath = `${folderPath}${fileName}.md`;

async function ensureFolder(path) {
  const parts = path.split("/").filter(Boolean);
  let cur = "";
  for (const p of parts) {
    cur += p + "/";
    try { 
      await app.vault.createFolder(cur); 
    } catch(e) { 
      // Folder already exists, continue
    }
  }
}

try {
  await ensureFolder(folderPath);
  if (tp.file.path(false) !== targetPath) { 
    await tp.file.move(targetPath); 
  }
} catch (error) {
  new Notice(`Error organizing file: ${error.message}`, 10000);
}
%>

<%*
/* --- PLUGIN CHECK: Required plugins --- */
const requiredPlugins = [
  { id: "dataview", name: "Dataview" },
  { id: "obsidian-tasks-plugin", name: "Tasks" },
  { id: "templater-obsidian", name: "Templater" }
];

const missingPlugins = requiredPlugins.filter(plugin => 
  !app.plugins.enabledPlugins.has(plugin.id)
);

if (missingPlugins.length > 0) {
  const pluginNames = missingPlugins.map(p => p.name).join(", ");
  new Notice(`⚠️ Missing required plugins: ${pluginNames}`, 15000);
}
%>

# 📅 <% tp.moment().format("YYYY-MM-DD") %> - <% tp.moment().format("dddd") %>

> [!TIP] **Daily Intention**
> *What's the one thing that, if accomplished, would make today a success?*

> [!INFO] **Quick Links**
> 📊 [[Weekly Review - <% tp.moment().format("YYYY-[W]WW") %>]] | 📈 [[Monthly Review - <% tp.moment().format("YYYY-MM") %>]] | 🗓️ [[<% tp.moment().subtract(1, 'day').format("YYYY-MM-DD") %>|Yesterday]] | [[<% tp.moment().add(1, 'day').format("YYYY-MM-DD") %>|Tomorrow]] 🗓️

---

## 🚀 Daily Dashboard

### 🎯 Top 3 Priorities
> Focus on your most important outcomes for today

1. [ ] 
2. [ ] 
3. [ ] 

### ✅ Systems & Operations Check
> Daily operational health checks

- [ ] Review monitoring dashboards and alerts
- [ ] Check CI/CD pipeline status and recent deployments
- [ ] Triage new incidents and alerts
- [ ] Review overnight batch job results
- [ ] Security vulnerability scan review
- [ ] Infrastructure capacity and performance check

### 📝 Task Management

**🔥 Overdue Tasks**
```tasks
not done
due before <% tp.moment().format("YYYY-MM-DD") %>
path does not include Templates
sort by due
limit 10
```

**📅 Due Today**
```tasks
not done
due on <% tp.moment().format("YYYY-MM-DD") %>
path does not include Templates
sort by priority
```

**⏰ Due This Week**
```tasks
not done
due after <% tp.moment().format("YYYY-MM-DD") %>
due before <% tp.moment().add(7, 'days').format("YYYY-MM-DD") %>
path does not include Templates
sort by due
limit 15
```

### 🏃‍♂️ In Progress
> What am I actively working on?

- [ ] 
- [ ] 
- [ ] 

### 📞 Meetings & Calls
> Scheduled interactions for today

| Time | Meeting | Attendees | Notes |
|------|---------|-----------|-------|
|      |         |           |       |

### 💡 Ideas & Notes
> Capture thoughts and insights

### 📈 Metrics & KPIs
> Track what matters

- **Incidents resolved:** 
- **Deployment success rate:** 
- **Response time (avg):** 
- **System uptime:** 

---

## 🌅 Morning Planning
*Fill this out at the start of your day*

**Energy Level:** ⚡⚡⚡⚡⚡ (1-5)
**Focus Areas:** 
**Potential Blockers:** 

## 🌆 Evening Reflection
*Review and plan for tomorrow*

**Accomplishments:**
- 
- 
- 

**Challenges:**
- 
- 

**Lessons Learned:**


**Tomorrow's Prep:**
- [ ] 
- [ ] 
- [ ] 

**Gratitude:**
1. 
2. 
3. 

---

## 📊 Daily Dataview Queries

### Recently Modified Files
```dataview
TABLE file.mtime as "Last Modified"
FROM ""
WHERE file.mtime >= date(today) - dur(1 day)
SORT file.mtime DESC
LIMIT 10
```

### Today's Created Tasks
```dataview
TASK
WHERE created = date(<% tp.moment().format("YYYY-MM-DD") %>)
GROUP BY file.link
