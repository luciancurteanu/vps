# Python Role

This role installs Python utilities and web automation tools for web scraping and browser automation tasks.

## Features

- Python 3 installation with pip package manager
- Chrome and ChromeDriver setup for browser automation
- Key Python packages for web scraping:
  - requests
  - cloudscraper
  - BeautifulSoup4
  - urllib3
  - selenium
  - selenium-stealth
  - webdriver-manager
  - undetected-chromedriver
- System dependencies for headless browser operation
- Proper permissions and configurations

## Requirements

- Ansible 2.9 or higher
- CentOS 9 Stream or compatible distribution
- Root access for package installation

## Role Variables

See `defaults/main.yml` for all available variables.

### Important variables:

```yaml
# Chrome and driver versions
chrome_version: "latest"
chromedriver_install_dir: "/usr/local/bin"

# Python packages
python_packages:
  - requests
  - cloudscraper
  - BeautifulSoup4
  - urllib3
  - selenium
  - selenium-stealth
  - webdriver-manager
  - undetected-chromedriver
```

## Web Scraping Capabilities

This role sets up a complete environment for web scraping and automation:

1. **Basic Scraping**: Using requests, BeautifulSoup4, and urllib3
2. **Anti-Bot Bypass**: Using cloudscraper for sites with anti-bot protection
3. **Full Browser Automation**: Using Selenium with Chrome
4. **Stealth Browsing**: Using selenium-stealth and undetected-chromedriver to avoid detection

## Example Python Script

After setup, you can use scripts like this for web automation:

```python
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

# Setup Chrome options
chrome_options = Options()
chrome_options.add_argument("--headless")  # Headless mode
chrome_options.add_argument("--no-sandbox")
chrome_options.add_argument("--disable-dev-shm-usage")

# Setup ChromeDriver service
service = Service(executable_path="/usr/local/bin/chromedriver")

# Start driver
driver = webdriver.Chrome(service=service, options=chrome_options)

# Navigate to a page
driver.get("https://vps.test")

# Extract information
title = driver.title
content = driver.find_element(By.TAG_NAME, "body").text

# Close the browser
driver.quit()

print(f"Title: {title}")
print(f"Content: {content[:100]}...")
```

## Example Playbook

```yaml
- hosts: servers
  roles:
    - role: python
```

## License

MIT