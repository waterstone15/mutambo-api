hbs = require('handlebars')

module.exports = (->

  template = """
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
          <title></title>
          <style type="text/css"></style>
        </head>
        <body>
          <p>Hello,</p>
          <p style="height: 2px;"></p>
          <p>We received a request to add this email, {{email}}, to an existing account. Click the link below to complete the request –</p>
          <p><a href="{{link}}">Add Email →</a></p>
          <p style="height: 2px;"></p>
          <p>If you did not request link, you can safely ignore this email.</p>
          <p style="height: 2px;"></p>
          <p>Thanks,</p>
          <p>– Mutambo Team</p>
          <p style="height: 2px;"></p>
          <p><i>If you have any questions or feedback, please reply to this email.</i></p>
        </body>
      </html>
  """

  return ({ email, link }) ->
    t = hbs.compile(template)
    return t({ email: email, link: link })

)()
