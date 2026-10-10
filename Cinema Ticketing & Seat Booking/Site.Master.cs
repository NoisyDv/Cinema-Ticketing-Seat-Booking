using System;
using System.Collections.Generic;
using System.Web.UI;

namespace Cinema_Ticketing___Seat_Booking
{
    public partial class SiteMaster : MasterPage
    {
        public class FlashItem
        {
            public bool IsError { get; set; }
            public string Text { get; set; }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            UserSession u = Auth.Current;
            bool loggedIn = u != null;
            phGuest.Visible = !loggedIn;
            phUser.Visible = loggedIn;
            lnkMyBookings.Visible = loggedIn;
            phAdmin.Visible = loggedIn && u.IsAdmin;
            if (loggedIn) litUserName.Text = Server.HtmlEncode(u.Name) + (u.IsAdmin ? " (admin)" : "");

            string path = Request.AppRelativeCurrentExecutionFilePath ?? "";
            MarkCurrent(lnkMovies, path.Equals("~/Default.aspx", StringComparison.OrdinalIgnoreCase));
            MarkCurrent(lnkMyBookings, path.Equals("~/MyBookings.aspx", StringComparison.OrdinalIgnoreCase));
            MarkCurrent(lnkAdmin, path.StartsWith("~/Admin/", StringComparison.OrdinalIgnoreCase));
            MarkCurrent(lnkLogin, path.Equals("~/Login.aspx", StringComparison.OrdinalIgnoreCase));
            MarkCurrent(lnkRegister, path.Equals("~/Register.aspx", StringComparison.OrdinalIgnoreCase));
        }

        static void MarkCurrent(System.Web.UI.WebControls.HyperLink link, bool isCurrent)
        {
            if (isCurrent) link.Attributes["aria-current"] = "page";
        }

        // แสดงข้อความ Flash ที่สะสมระหว่างการประมวลผลหน้า (PreRender = หลัง event ของหน้าทำงานครบแล้ว)
        protected void Page_PreRender(object sender, EventArgs e)
        {
            List<FlashItem> items = new List<FlashItem>();
            foreach (KeyValuePair<bool, string> kv in Flash.TakeAll())
                items.Add(new FlashItem { IsError = kv.Key, Text = kv.Value });
            rptFlash.DataSource = items;
            rptFlash.DataBind();
        }

        protected void btnLogout_Click(object sender, EventArgs e)
        {
            Auth.SignOut();
            Response.Redirect("~/Login.aspx?out=1", false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
