sitemaps.add "/sitemap.xml", ->
  map = [
    {
      page: ""
      lastmod: new Date()
      priority: 0.2
      changefreq: "monthly"
    }
    {
      page: "mm"
      lastmod: new Date()
      priority: 0.8
      changefreq: "weekly"
    }
    {
      page: "lb"
      lastmod: new Date()
      priority: 0.5
      changefreq: "monthly"
    }
  ]
