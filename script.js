// Tab navigation
document.querySelectorAll('.nav-link').forEach(link => {
  link.addEventListener('click', e => {
    e.preventDefault();
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    link.classList.add('active');
    document.getElementById(link.dataset.tab).classList.add('active');
    // Reset blog to list view when navigating to blog tab
    if (link.dataset.tab === 'blog') showBlogList();
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

// ============ BLOG ============
// To add a new post: create a .md file in blog/ and add an entry here.
const blogPosts = [
  {
    slug: 'cloud-resume-challenge',
    title: 'How I Built My Cloud Resume on AWS',
    date: '2026-03-31',
    summary: 'A walkthrough of building a full-stack serverless website using S3, CloudFront, Lambda, DynamoDB, and CloudFormation.',
    file: 'blog/cloud-resume-challenge.md'
  }
];

function showBlogList() {
  const list = document.getElementById('blog-list');
  const post = document.getElementById('blog-post');
  list.style.display = '';
  post.style.display = 'none';

  list.innerHTML = blogPosts.map(p => `
    <article class="blog-card" data-slug="${p.slug}">
      <h3>${p.title}</h3>
      <p class="blog-date">${new Date(p.date).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</p>
      <p class="blog-summary">${p.summary}</p>
      <span class="blog-read-more">Read more →</span>
    </article>
  `).join('');

  list.querySelectorAll('.blog-card').forEach(card => {
    card.addEventListener('click', () => loadBlogPost(card.dataset.slug));
  });
}

async function loadBlogPost(slug) {
  const entry = blogPosts.find(p => p.slug === slug);
  if (!entry) return;

  const list = document.getElementById('blog-list');
  const post = document.getElementById('blog-post');
  const content = document.getElementById('blog-content');

  try {
    const res = await fetch(entry.file);
    if (!res.ok) throw new Error('Not found');
    const md = await res.text();
    content.innerHTML = marked.parse(md);
    list.style.display = 'none';
    post.style.display = '';
  } catch {
    content.innerHTML = '<p>Could not load this post.</p>';
    list.style.display = 'none';
    post.style.display = '';
  }
}

document.getElementById('blog-back').addEventListener('click', showBlogList);

// Initialize blog list on page load
showBlogList();
