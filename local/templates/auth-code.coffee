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
          <table border="0" cellspacing="0" width="100%">
            <tr>
              <td width="450">
                <p>Hello,</p>
                <p style='height: 2px;'></p>
                <p style='line-height: 160%;'>We received a request to sign in to Mutambo using this email address. Use the following code to sign in to your {{email}} account –</p>
                <p style='height: 2px;'></p>
                <p style='background-color: #fafafa; padding: 10px 10px 10px 10px; margin: 0px 0px 0px 0px; font-family: monospace, monospace; font-weight: bold'>{{ code }}</p>
                <p style='height: 2px;'></p>
                <p style='line-height: 160%;'>If you did not make this request, you can safely ignore this email. This link code expire in a few minutes.</p>
                <p style='height: 2px;'></p>
                <p>Thanks,</p>
                <p>– Mutambo Team</p>
                <p style='height: 2px;'></p>
                <p style='line-height: 160%;'><i>If you have any questions or feedback, please reply to this email.</i></p>
              </td>
              <td></td>
            </tr>
          </table>
        </body>
      </html>
  """

  return ({ email, code }) ->
    t = hbs.compile(template)
    return t({ email, code })

)()
