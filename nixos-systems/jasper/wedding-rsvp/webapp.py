import sys
from flask import Flask
from flask import request

app = Flask(__name__)

@app.route('/rsvp', methods = ['POST'] )
def site():
    print(f"Received post request: {str(request.form)}")
    return "OK"

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=int(sys.argv[2]))
