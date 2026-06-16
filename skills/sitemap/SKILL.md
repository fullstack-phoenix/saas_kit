---
name: sitemap
description: Use when the app needs an XML sitemap and robots.txt for search-engine indexing. Covers installing a Phoenix SitemapController, the XML template, and how to add static or dynamic URLs.
user-invocable: true
---

# XML Sitemaps

Serves an XML sitemap at `/sitemap.xml` using a plain Phoenix controller and an
EEx template, and wires `robots.txt` to point at it. No external dependencies —
it adds the `:xml` format to the web entrypoint, a route, a `SitemapController`,
a `SitemapXML` view, and the template you edit to list your URLs.

## When to use

- The app is public and you want search engines to discover its pages.
- You need a standards-compliant (sitemaps.org) sitemap served with the correct
  XML content type.
- Don't bother for an internal/admin-only app with no indexable public pages.

## Dependencies

- Requires: None.
- Recommended: None.

## Install

```bash
mix saaskit.feature.install sitemap
```

No installer decisions. It injects the `:xml` format and route, appends the
`Sitemap:` line to `robots.txt`, and generates the controller, view, template,
and test.

## What it generates

- `lib/my_app_web/controllers/sitemap_controller.ex` — `index/2` renders
  `index.xml` with `layout: false` and `text/xml` content type.
- `lib/my_app_web/controllers/sitemap_xml.ex` — `SitemapXML` view using
  `embed_templates "sitemap_xml/*"`.
- `lib/my_app_web/controllers/sitemap_xml/index.xml.eex` — the sitemap template
  (one `<url>` entry for `/` by default).
- `test/my_app_web/controllers/sitemap_controller_test.exs` — asserts the route
  returns XML.
- Adds `:xml` to the allowed formats in `lib/my_app_web.ex`.
- Adds `get "/sitemap.xml", SitemapController, :index` to `lib/my_app_web/router.ex`.
- Appends `Sitemap: https://example.com/sitemap.xml` to `priv/static/robots.txt`.

## Configuration

No config keys. The only value to change is the domain in
`priv/static/robots.txt`:

```text
Sitemap: https://example.com/sitemap.xml
```

Replace `example.com` with your production domain.

## Tweaking for your app

Add static routes to the template:

```eex
<%# lib/my_app_web/controllers/sitemap_xml/index.xml.eex %>
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="https://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc><%= url(~p"/") %></loc>
    <changefreq>daily</changefreq>
    <priority>1</priority>
  </url>
  <url>
    <loc><%= url(~p"/pricing") %></loc>
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>
```

For dynamic content, query in the controller and pass it to the template:

```elixir
# lib/my_app_web/controllers/sitemap_controller.ex
def index(conn, _params) do
  conn
  |> put_resp_content_type("text/xml")
  |> render("index.xml", layout: false, posts: MyApp.Blog.list_posts())
end
```

```eex
<%# lib/my_app_web/controllers/sitemap_xml/index.xml.eex %>
<%= for post <- @posts do %>
  <url>
    <loc><%= url(~p"/blog/#{post.slug}") %></loc>
    <changefreq>weekly</changefreq>
    <priority>0.6</priority>
  </url>
<% end %>
```

## After install

- [ ] `mix saaskit.feature.install sitemap`
- [ ] Replace `example.com` in `priv/static/robots.txt` with your production domain.
- [ ] Edit `lib/my_app_web/controllers/sitemap_xml/index.xml.eex` to list important URLs.
- [ ] If you have dynamic content, query it in the controller and pass it to the template.
- [ ] After deploy, submit `https://<your-domain>/sitemap.xml` to Google Search Console.
- [ ] Verify the sitemap validates against the sitemaps.org schema.
