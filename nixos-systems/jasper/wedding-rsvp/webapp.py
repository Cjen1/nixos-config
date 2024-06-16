import sys
from flask import Flask
from flask import request
import requests

web = { 'api': '7a6d1a68ea349ff6d4ecebc93c16c246af9fb9c7',
        'url':  "https://docs.getgrist.com/api/docs/eXNCAMGkjMh5eomzX3SuzR/tables/Rsvp/records",
        }
local = { 'api': 'a3eb369ea2d33c32ce16c6de3cd3f77a5e13f7d6',
          'url':  "http://192.168.1.101:8484/api/docs/wEjSZMn7f6Cg/tables/Rsvp/records"}

app = Flask(__name__)

def send_post(request, ctx):
    api = ctx['api']
    headers = {'accept': 'application/json',
               'Authorization': f'Bearer {api}',
               'Content-Type': 'application/json'}
    return requests.post(ctx['url'], headers=headers, json={'records':[{"fields":request.form}]})

log_path = "/dev/null"

@app.route('/rsvp', methods = ['POST'] )
def site():
    global log_path
    try:
        with open(log_path, 'a') as fd:
            fd.write(f'{str(request.origin)}\n{str(request.form)}\n')
        send_post(request, web).raise_for_status()
        send_post(request, local).raise_for_status()
        print("OK")
        return "OK"
    except requests.exceptions.HTTPError as err:
        print(err)
        return "Failed to write to DBs"

if __name__ == '__main__':
    log_path = sys.argv[3]
    app.run(host="0.0.0.0", port=int(sys.argv[2]))
