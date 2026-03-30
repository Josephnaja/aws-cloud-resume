// Tab navigation
document.querySelectorAll('.nav-link').forEach(link => {
  link.addEventListener('click', e => {
    e.preventDefault();
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    link.classList.add('active');
    document.getElementById(link.dataset.tab).classList.add('active');
  });
});

// Visitor counter — routed through CloudFront to API Gateway
async function updateVisitorCount() {
  const counter = document.getElementById('visitor-count');
  try {
    const res = await fetch('/api/counter');
    const data = await res.json();
    counter.textContent = data.count;
  } catch {
    counter.textContent = '—';
  }
}

updateVisitorCount();
