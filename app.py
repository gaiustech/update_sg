#!/bin/env python

"""Trivial app that returns the IP address of the caller via HTTP"""

from bottle import get, request, response, run

@get('/whatsmyip')
def index():
    """Find the IP address of the requester and return it"""
    response.content_type='text/plain'
    return request['REMOTE_ADDR']

if __name__ == '__main__':
    run(host='0.0.0.0', port=8080)

# End of file
