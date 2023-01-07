import random as rd

f_DRAM = open("./dram.dat", "w")

C_STATUS = [0, 1, 3]
D_INFO_TYPE = [0, 1, 2]
FOOD_ID = [1, 2, 3]

def fill_with_zeros(s, t):
    ss = ""
    for i in range(t-len(s)):
        ss += "0"
    
    ss += s
    return ss
    
def four_bin_to_hex(s):
    ss1 = ""
    ss2 = ""
    sl = []
    for i in range(len(s)):
        if i <= 7:
            ss1 += s[i]
        elif i > 7 and i < len(s):
            ss2 += s[i]
        
    sl.append(hex(int(ss1, 2))[2:4])
    sl.append(hex(int(ss2, 2))[2:4])
    # print(sl[0], sl[1])
    return sl

def GEN_DRAM():
    flag = True
    for i in range(0x10000, 0x107FF, 4) :
        if flag:
            f_DRAM.write('@' + format(i, 'x') + '\n')
            temp1 = hex(rd.randint(120, 255))[2:4] # limit of order of the restaurant
            temp2 = hex(rd.randint(10, 100))[2:4]
            temp3 = hex(rd.randint(0, (int(temp1, 16)-int(temp2, 16)-1)))[2:4]
            temp4 = hex(rd.randint(0, (int(temp1, 16)-int(temp2, 16)-int(temp3, 16)-1)))[2:4]
            f_DRAM.write(temp1 + ' ' + temp2 + ' ' + temp3 + ' ' + temp4 + '\n')
            flag = False
            
        elif not flag:
            f_DRAM.write('@' + format(i, 'x') + '\n')
            temp1 = hex(0)[2:4]
            temp2 = hex(0)[2:4]
            temp3 = hex(0)[2:4]
            temp4 = hex(0)[2:4]
            
            type = rd.randint(0, 2)
            # no customer
            if type == 0:
                temp1 = hex(0)[2:4]
                temp2 = hex(0)[2:4]
                temp3 = hex(0)[2:4]
                temp4 = hex(0)[2:4]
            
            # only have custom_1
            elif type == 1:
                status = rd.randint(1, 2)
                food_id = rd.randint(0, 2)
                c1_status = fill_with_zeros(str(bin(C_STATUS[status])[2:]), 2)
                c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
                c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
                c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
                
                # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))
                temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)
                
                
                temp1 = temp12[0]
                temp2 = temp12[1]
                temp3 = hex(0)[2:4]
                temp4 = hex(0)[2:4]
                
            # have custom_1 and custom_2
            elif type == 2:
                status1 = rd.randint(1, 2)
                food_id = rd.randint(0, 2)
                c1_status = fill_with_zeros(str(bin(C_STATUS[status1])[2:]), 2)
                c1_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
                c1_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
                c1_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
                # print(fill_with_zeros(c1_status, 2), fill_with_zeros(c1_res_id, 8), fill_with_zeros(c1_food_id, 2), fill_with_zeros(c1_order, 4))
                
                temp12 = four_bin_to_hex(c1_status + c1_res_id + c1_food_id + c1_order)
                
                temp1 = temp12[0]
                temp2 = temp12[1]
                status2 = 0
                if status1 == 2:
                    status2 = rd.randint(1, 2)
                elif status1 == 1:
                    status2 = 1
                food_id = rd.randint(0, 2)
                c2_status = fill_with_zeros(str(bin(C_STATUS[status2])[2:]), 2)
                c2_res_id = fill_with_zeros(str(bin(rd.randint(0, 255))[2:]), 8)
                c2_food_id = fill_with_zeros(str(bin(FOOD_ID[food_id])[2:]), 2)
                c2_order = fill_with_zeros(str(bin(rd.randint(1, 15))[2:]), 4)
                # print(fill_with_zeros(c2_status, 2), fill_with_zeros(c2_res_id, 8), fill_with_zeros(c2_food_id, 2), fill_with_zeros(c2_order, 4))
                
                temp34 = four_bin_to_hex(c2_status + c2_res_id + c2_food_id + c2_order)
                
                temp3 = temp34[0]
                temp4 = temp34[1]
                
                # print(temp1, temp2, temp3, temp4)

            f_DRAM.write(temp1 + ' ' + temp2 + ' ' + temp3 + ' ' + temp4 + '\n')
            flag = True
            

if __name__ == '__main__' :
    GEN_DRAM()

f_DRAM.close()