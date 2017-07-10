require 'scraperwiki'
require 'mechanize'

url = "http://www.yarracity.vic.gov.au/Planning-Application-Search/Results.aspx?ApplicationNumber=&Suburb=(All)&Street=(All)&Status=Current&Ward=(All)"

def clean_whitespace(a)
  a.gsub("\r", ' ').gsub("\n", ' ').squeeze(" ").strip
end

def get_page_data(page)
  comment_url = "mailto:info@yarracity.vic.gov.au"

  trs = page.search('table#ContentPlaceHolder_dgResults/tr')
  trs[1..-2].each do |tr|
    texts = tr.search('td').map{|n| n.inner_text}
    council_reference = clean_whitespace(texts[0])
    info_url = "http://www.yarracity.vic.gov.au/Planning-Application-Search/Results.aspx?ApplicationNumber=#{council_reference}&Suburb=(All)&Street=(All)&Status=(All)&Ward=(All)"
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

page = agent.get(url)

current_page = 1
begin
  get_page_data(page)

  # Click on the link to the next page
  links = page.search('table tr')[-1].search('a')
  link = links.find{|a| a.inner_text.to_i == current_page + 1}
  # This page has a really odd paging mechanism
  if link.nil? 
    # Ignore the first link in case it's a "..." as well that will go back rather than forward
    link = links[1..-1].find{|a| a.inner_text == "..."}
  end
  if link
    href = link["href"]
    matches = href.match(/javascript:__doPostBack\('(.*)','(.*)'\)/)
    # We're faking what the __doPostBack javascript does
    form = page.forms.first
    form["__EVENTTARGET"] = matches[1]
    form["__EVENTARGUMENT"] = matches[2]
    page = form.submit
    current_page += 1
  end
end while link

