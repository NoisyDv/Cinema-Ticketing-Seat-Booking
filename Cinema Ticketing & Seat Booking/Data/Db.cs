using System.Configuration;
using System.Data.SqlClient;

namespace Cinema_Ticketing___Seat_Booking.Data
{
    // ตัวช่วยเปิด connection เดียวของเว็บ
    // ใช้ connection string ชื่อ MoviesConnectionString ใน Web.config
    // (ชี้ไป SQL Server ที่รัน Database/schema.sql + data.sql + logic.sql แล้ว)
    public static class Db
    {
        public static string ConnectionString
        {
            get
            {
                var cs = ConfigurationManager.ConnectionStrings["MoviesConnectionString"];
                return cs != null ? cs.ConnectionString : null;
            }
        }

        public static SqlConnection Open()
        {
            var conn = new SqlConnection(ConnectionString);
            conn.Open();
            return conn;
        }
    }
}
