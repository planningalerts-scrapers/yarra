require 'scraperwiki'
require 'mechanize'

url_base = "https://www.yarracity.vic.gov.au/planning-application-search"
url = url_base + "?suburb=(All)&street=(All)&status=Current&ward=(All)"

def clean_whitespace(a)
  a.gsub("\r", ' ').gsub("\n", ' ').squeeze(" ").strip
end

def get_page_data(page, url_base)
  comment_url = "mailto:info@yarracity.vic.gov.au"

  trs = page.search('table.search tbody tr')
  trs.each do |tr|
    texts = tr.search('td').map{|n| n.inner_text}
    council_reference = clean_whitespace(texts[0])

    info_url = url_base + "?applicationNumber=#{council_reference}"
    record = {
      'info_url' => info_url,
      'comment_url' => comment_url,
      'council_reference' => council_reference,
      'date_received' => Date.parse(texts[1]).to_s,
      'address' => clean_whitespace(texts[2]),
      'description' => clean_whitespace(texts[3]),
      'date_scraped' => Date.today.to_s
    }
    begin
      record["on_notice_from"] = Date.parse(texts[4]).to_s
    rescue
      # In case the date is invalid
    end

    if ( ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true )
      puts "Saving record " + council_reference + " - " + record['address']
#       puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference'] + " - " + record['address']
    end
  end
end

agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

page = agent.get url

begin
  get_page_data(page, url_base)

  # Click on the link to the next page
  links = page.search('div.pagination-container').search('a')
  link = links.find{|a| a.inner_text == 'Next'}

  if link
    puts url_base + link["href"]
    page = agent.get (url_base + link["href"])
  end
  # end

end while link

